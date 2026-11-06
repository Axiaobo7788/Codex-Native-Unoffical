use std::env;
use std::io::{self, BufRead, Write};

fn main() -> io::Result<()> {
    let output_bytes = env::var("CODEX_NATIVE_FIXTURE_BYTES")
        .map_err(|_| io::Error::other("CODEX_NATIVE_FIXTURE_BYTES is required"))?
        .parse::<usize>()
        .map_err(|_| io::Error::other("fixture byte count must be an integer"))?;
    let stdin = io::stdin();
    let mut stdout = io::BufWriter::new(io::stdout());
    let mut item_list_response_id = 2_u64;

    for line in stdin.lock().lines() {
        let line = line?;
        if line.contains("\"method\":\"initialize\"") {
            stdout
                .write_all(b"{\"id\":1,\"result\":{\"userAgent\":\"large-output-fixture/1\"}}\n")?;
            stdout.flush()?;
        } else if line.contains("\"method\":\"thread/items/list\"") {
            // Deliberately retain the source value while serializing a second
            // complete response String. This approximates the reviewed stock
            // app-server object + serde_json::to_string allocation shape.
            let aggregated_output = "x".repeat(output_bytes);
            let response = format!(
                "{{\"id\":{item_list_response_id},\"result\":{{\"data\":[{{\"turnId\":\"turn-fixture\",\"item\":{{\"id\":\"command-fixture\",\"type\":\"commandExecution\",\"command\":\"fixture\",\"aggregatedOutput\":\"{aggregated_output}\",\"status\":\"completed\"}}}}],\"nextCursor\":null}}}}\n"
            );
            item_list_response_id += 1;
            stdout.write_all(response.as_bytes())?;
            stdout.flush()?;
        }
    }
    Ok(())
}
