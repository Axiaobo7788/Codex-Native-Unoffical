use std::io;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum DecodeState {
    Normal,
    Escape,
    Unicode { value: u16, digits: u8 },
    LowSurrogateSlash { high: u16 },
    LowSurrogateU { high: u16 },
    LowSurrogate { high: u16, value: u16, digits: u8 },
}

/// Incrementally decodes the raw bytes between JSON string quotes.
///
/// JSON grammar and raw UTF-8 validity are checked by `json-skimmer`. This
/// decoder owns the additional semantic work required to turn escapes into the
/// exact UTF-8 bytes written to an output spool. Fragment boundaries are never
/// significant.
#[derive(Debug)]
pub(crate) struct JsonStringDecoder {
    state: DecodeState,
}

impl Default for JsonStringDecoder {
    fn default() -> Self {
        Self {
            state: DecodeState::Normal,
        }
    }
}

impl JsonStringDecoder {
    pub(crate) fn feed(
        &mut self,
        bytes: &[u8],
        mut emit: impl FnMut(&[u8]) -> io::Result<()>,
    ) -> io::Result<()> {
        let mut raw_start = 0;
        for (index, byte) in bytes.iter().copied().enumerate() {
            match self.state {
                DecodeState::Normal if byte != b'\\' => continue,
                DecodeState::Normal => {
                    if raw_start < index {
                        emit(&bytes[raw_start..index])?;
                    }
                    self.state = DecodeState::Escape;
                    raw_start = index + 1;
                }
                DecodeState::Escape => {
                    let decoded = match byte {
                        b'"' => b'"',
                        b'\\' => b'\\',
                        b'/' => b'/',
                        b'b' => 0x08,
                        b'f' => 0x0c,
                        b'n' => b'\n',
                        b'r' => b'\r',
                        b't' => b'\t',
                        b'u' => {
                            self.state = DecodeState::Unicode {
                                value: 0,
                                digits: 0,
                            };
                            raw_start = index + 1;
                            continue;
                        }
                        _ => return Err(invalid_string("invalid JSON escape")),
                    };
                    emit(&[decoded])?;
                    self.state = DecodeState::Normal;
                    raw_start = index + 1;
                }
                DecodeState::Unicode { value, digits } => {
                    let value = (value << 4) | hex(byte)? as u16;
                    let digits = digits + 1;
                    if digits < 4 {
                        self.state = DecodeState::Unicode { value, digits };
                    } else if (0xd800..=0xdbff).contains(&value) {
                        self.state = DecodeState::LowSurrogateSlash { high: value };
                    } else if (0xdc00..=0xdfff).contains(&value) {
                        return Err(invalid_string("unpaired low surrogate"));
                    } else {
                        emit_scalar(value as u32, &mut emit)?;
                        self.state = DecodeState::Normal;
                    }
                    raw_start = index + 1;
                }
                DecodeState::LowSurrogateSlash { high } => {
                    if byte != b'\\' {
                        return Err(invalid_string("high surrogate is not paired"));
                    }
                    self.state = DecodeState::LowSurrogateU { high };
                    raw_start = index + 1;
                }
                DecodeState::LowSurrogateU { high } => {
                    if byte != b'u' {
                        return Err(invalid_string("high surrogate is not followed by \\u"));
                    }
                    self.state = DecodeState::LowSurrogate {
                        high,
                        value: 0,
                        digits: 0,
                    };
                    raw_start = index + 1;
                }
                DecodeState::LowSurrogate {
                    high,
                    value,
                    digits,
                } => {
                    let value = (value << 4) | hex(byte)? as u16;
                    let digits = digits + 1;
                    if digits < 4 {
                        self.state = DecodeState::LowSurrogate {
                            high,
                            value,
                            digits,
                        };
                    } else {
                        if !(0xdc00..=0xdfff).contains(&value) {
                            return Err(invalid_string("invalid low surrogate"));
                        }
                        let scalar =
                            0x10000 + (((high as u32 - 0xd800) << 10) | (value as u32 - 0xdc00));
                        emit_scalar(scalar, &mut emit)?;
                        self.state = DecodeState::Normal;
                    }
                    raw_start = index + 1;
                }
            }
        }

        if self.state == DecodeState::Normal && raw_start < bytes.len() {
            emit(&bytes[raw_start..])?;
        }
        Ok(())
    }

    pub(crate) fn finish(&self) -> io::Result<()> {
        if self.state == DecodeState::Normal {
            Ok(())
        } else {
            Err(invalid_string("truncated JSON escape"))
        }
    }
}

fn hex(byte: u8) -> io::Result<u8> {
    match byte {
        b'0'..=b'9' => Ok(byte - b'0'),
        b'a'..=b'f' => Ok(byte - b'a' + 10),
        b'A'..=b'F' => Ok(byte - b'A' + 10),
        _ => Err(invalid_string("invalid Unicode escape digit")),
    }
}

fn emit_scalar(scalar: u32, emit: &mut impl FnMut(&[u8]) -> io::Result<()>) -> io::Result<()> {
    let character = char::from_u32(scalar)
        .ok_or_else(|| invalid_string("Unicode escape is not a scalar value"))?;
    let mut buffer = [0_u8; 4];
    emit(character.encode_utf8(&mut buffer).as_bytes())
}

fn invalid_string(message: &'static str) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, message)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn decode(input: &[u8], split: usize) -> io::Result<Vec<u8>> {
        let mut decoder = JsonStringDecoder::default();
        let mut output = Vec::new();
        for chunk in input.chunks(split) {
            decoder.feed(chunk, |bytes| {
                output.extend_from_slice(bytes);
                Ok(())
            })?;
        }
        decoder.finish()?;
        Ok(output)
    }

    #[test]
    fn decodes_all_escapes_across_every_fragment_size() {
        let input = br#"plain\"quote\\slash\/\b\f\n\r\t\u0041\u4f60\ud83d\ude80"#;
        let expected = "plain\"quote\\slash/\u{8}\u{c}\n\r\tA你🚀".as_bytes();
        for split in 1..=input.len() {
            assert_eq!(decode(input, split).unwrap(), expected, "split={split}");
        }
    }

    #[test]
    fn rejects_unpaired_and_truncated_surrogates() {
        for invalid in [br#"\ud83d"#.as_slice(), br#"\ude80"#, br#"\ud83d\u0041"#] {
            assert!(decode(invalid, 1).is_err());
        }
        assert!(decode(br#"\u12"#, 1).is_err());
    }
}
