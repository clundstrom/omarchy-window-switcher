mod core;
#[cfg(test)]
mod tests;

use serde::Deserialize;
use serde_json::json;

#[cxx::bridge(namespace = "workspace_switcher")]
mod ffi {
    extern "Rust" {
        fn evaluate(operation: &str, input: &str) -> String;
        fn step(index: i32, direction: i32, count: i32) -> i32;
    }
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct Focus {
    mru_keys: Vec<String>,
    workspace_history: Vec<String>,
    live_keys: Vec<String>,
    key: String,
    workspace_id: Option<i64>,
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
struct WorkspaceFocus {
    keys: Vec<String>,
    workspace_id: Option<i64>,
}

fn evaluate(operation: &str, input: &str) -> String {
    // No window objects, image data or application text crosses this bridge.
    if input.len() > 1_048_576 {
        return json!({"error": "Workspace data exceeds the native input limit"}).to_string();
    }
    let result: Result<serde_json::Value, serde_json::Error> = match operation {
        "refresh" => serde_json::from_str(input).map(|input: core::Refresh| json!(core::refresh(input))),
        "layout" => serde_json::from_str(input).map(|windows: Vec<Option<core::Window>>| json!(core::layout(&windows))),
        "focus" => serde_json::from_str(input).map(|input: Focus| json!({
            "mruKeys": core::note_window(&input.mru_keys, &input.key, &input.live_keys),
            "workspaceHistory": core::note_workspace(&input.workspace_history, input.workspace_id),
        })),
        "workspaceFocus" => serde_json::from_str(input).map(|input: WorkspaceFocus| json!(core::note_workspace(&input.keys, input.workspace_id))),
        _ => return json!({"error": "Unknown workspace operation"}).to_string(),
    };
    result
        .unwrap_or_else(|_| json!({"error": "Invalid workspace data"}))
        .to_string()
}

fn step(index: i32, direction: i32, count: i32) -> i32 {
    core::step(index, direction, count)
}
