use serde_json::{Value, json};

// FileUpdateChange.kind may follow diff in JSON. Measure both raw content and
// unified hunks without retaining the body or depending on object key order.
#[derive(Default)]
pub(crate) struct FileDiffMetrics {
    prefix: [u8; 11],
    prefix_len: usize,
    in_hunk: bool,
    content_lines: u64,
    additions: u64,
    deletions: u64,
}

impl FileDiffMetrics {
    pub(crate) fn feed(&mut self, bytes: &[u8]) {
        for &byte in bytes {
            if byte == b'\n' {
                self.finish_line();
            } else if self.prefix_len < self.prefix.len() {
                self.prefix[self.prefix_len] = byte;
                self.prefix_len += 1;
            }
        }
    }

    pub(crate) fn finish(mut self) -> Value {
        if self.prefix_len != 0 {
            self.finish_line();
        }
        json!({
            "contentLines": self.content_lines,
            "additions": self.additions,
            "deletions": self.deletions,
        })
    }

    fn finish_line(&mut self) {
        self.content_lines = self.content_lines.saturating_add(1);
        let prefix = &self.prefix[..self.prefix_len];
        if prefix.starts_with(b"@@") {
            self.in_hunk = true;
        } else if prefix == b"diff --git " {
            self.in_hunk = false;
        } else if prefix.first() == Some(&b'+') && (self.in_hunk || !prefix.starts_with(b"+++")) {
            self.additions = self.additions.saturating_add(1);
        } else if prefix.first() == Some(&b'-') && (self.in_hunk || !prefix.starts_with(b"---")) {
            self.deletions = self.deletions.saturating_add(1);
        }
        self.prefix_len = 0;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn raw_content_and_patch_stats_are_independent_of_fragments() {
        let content = "- bullet\r\n+literal\r\n\r\n";
        let patch = "--- a/file\n+++ b/file\n@@ -1 +1 @@\n---old\n+++新\n";
        for size in 1..=24 {
            for (body, expected) in [
                (
                    content,
                    json!({"contentLines": 3, "additions": 1, "deletions": 1}),
                ),
                (
                    patch,
                    json!({"contentLines": 5, "additions": 1, "deletions": 1}),
                ),
            ] {
                let mut metrics = FileDiffMetrics::default();
                for chunk in body.as_bytes().chunks(size) {
                    metrics.feed(chunk);
                }
                assert_eq!(metrics.finish(), expected, "chunk size {size}");
            }
        }
    }

    #[test]
    fn empty_trailing_and_unterminated_lines_have_no_phantom_line() {
        for (body, expected) in [
            ("", 0),
            ("\n", 1),
            ("\n\n", 2),
            ("a\n", 1),
            ("a\r\n", 1),
            ("a\n\nb", 3),
        ] {
            let mut metrics = FileDiffMetrics::default();
            metrics.feed(body.as_bytes());
            assert_eq!(metrics.finish()["contentLines"], expected);
        }
        let mut metrics = FileDiffMetrics::default();
        metrics.feed(b"@@ -1 +1 @@\n-old\n+new");
        assert_eq!(
            metrics.finish(),
            json!({"contentLines": 3, "additions": 1, "deletions": 1})
        );
    }

    #[test]
    fn another_file_header_retires_hunk_state_with_constant_prefix_storage() {
        let mut metrics = FileDiffMetrics::default();
        metrics.feed(b"@@ -1 +1 @@\n-old\n+new\ndiff --git a/b b/b\n--- a/b\n+++ b/b\n");
        for _ in 0..4096 {
            metrics.feed(&[b'x'; 1024]);
        }
        assert_eq!(metrics.prefix_len, 11);
        assert_eq!(
            metrics.finish(),
            json!({"contentLines": 7, "additions": 1, "deletions": 1})
        );
    }
}
