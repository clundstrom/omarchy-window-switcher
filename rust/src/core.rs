use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};

#[derive(Clone, Debug, Default, Deserialize, Serialize, PartialEq)]
#[serde(default)]
pub struct Rect {
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}

#[derive(Clone, Debug, Default, Deserialize, Serialize)]
#[serde(default, rename_all = "camelCase")]
pub struct Window {
    pub key: String,
    pub title: String,
    pub app_id: String,
    pub app_key: String,
    pub app_name: String,
    pub app_icon: String,
    pub source_token: String,
    pub source_index: f64,
    pub workspace_id: Option<i64>,
    pub workspace_name: String,
    pub monitor_id: Option<i64>,
    pub monitor_name: String,
    pub minimized: bool,
    pub rect: Option<Rect>,
    pub monitor_rect: Option<Rect>,
}

#[derive(Debug, Default, Deserialize)]
#[serde(default, rename_all = "camelCase")]
pub struct Refresh {
    pub window_mode: bool,
    pub application_mode: bool,
    pub overview_app: Option<String>,
    pub rows: Vec<Window>,
    pub mru_keys: Vec<String>,
    pub workspace_history: Vec<String>,
    pub frozen_history: Vec<String>,
    pub focused_workspace_id: Option<i64>,
    pub active_key: Option<String>,
    pub opened: bool,
    pub opening_direction: Option<i32>,
    pub previous_windows: Vec<Window>,
    pub selected_key: String,
    pub selected_index: i32,
}

#[derive(Debug, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct Group {
    pub key: String,
    pub id: i64,
    pub label: String,
    pub start_index: usize,
    pub size: usize,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Snapshot {
    pub mru_keys: Vec<String>,
    pub workspace_history: Vec<String>,
    pub frozen_history: Vec<String>,
    pub window_order: Vec<usize>,
    pub workspace_order: Vec<usize>,
    pub groups: Vec<Group>,
    pub selected_index: i32,
    pub changed: bool,
}

pub fn step(index: i32, direction: i32, count: i32) -> i32 {
    if count <= 0 {
        return -1;
    }
    (i64::from(index) + if direction < 0 { -1 } else { 1 }).rem_euclid(i64::from(count)) as i32
}

pub fn prune_history(keys: &[String], live: &[String], limit: usize) -> Vec<String> {
    let live: HashSet<&str> = live.iter().map(String::as_str).collect();
    let mut seen = HashSet::new();
    keys.iter()
        .filter(|key| !key.is_empty() && live.contains(key.as_str()) && seen.insert(key.as_str()))
        .take(limit)
        .cloned()
        .collect()
}

pub fn note_window(keys: &[String], key: &str, live: &[String]) -> Vec<String> {
    let mut next = Vec::with_capacity(keys.len() + 1);
    if !key.is_empty() {
        next.push(key.to_owned());
    }
    next.extend(keys.iter().filter(|value| value.as_str() != key).cloned());
    prune_history(&next, live, 200)
}

pub fn note_workspace(keys: &[String], workspace_id: Option<i64>) -> Vec<String> {
    let Some(id) = workspace_id else {
        return keys.iter().take(100).cloned().collect();
    };
    let mut next = vec![id.to_string()];
    for key in keys {
        let key = key.trim();
        if !key.is_empty() && !next.iter().any(|value| value == key) {
            next.push(key.to_owned());
        }
        if next.len() >= 100 {
            break;
        }
    }
    next
}

fn regular_window(row: &Window) -> bool {
    !row.minimized
        && row.workspace_id.is_some_and(|id| id > 0)
        && !row.workspace_name.starts_with("special:")
}

fn target_key(row: &Window, application_mode: bool) -> String {
    if !application_mode {
        return row.key.clone();
    }
    let id = if row.app_key.is_empty() {
        &row.app_id
    } else {
        &row.app_key
    };
    if id.is_empty() {
        format!("window:{}", row.key)
    } else {
        format!("app:{id}")
    }
}

fn eligible_target(row: &Window, overview_app: Option<&str>) -> bool {
    regular_window(row) && overview_app.is_none_or(|app| target_key(row, true) == app)
}

fn same_application(left: &Window, right: &Window) -> bool {
    left.key == right.key
        && left.source_token == right.source_token
        && left.workspace_id == right.workspace_id
        && left.minimized == right.minimized
        && left.app_id == right.app_id
        && left.app_key == right.app_key
        && left.app_name == right.app_name
        && left.app_icon == right.app_icon
}

fn same_preview(left: &Window, right: &Window) -> bool {
    left.key == right.key
        && left.source_token == right.source_token
        && left.workspace_id == right.workspace_id
        && left.workspace_name == right.workspace_name
        && left.monitor_id == right.monitor_id
        && left.monitor_name == right.monitor_name
        && left.minimized == right.minimized
        && left.rect == right.rect
        && left.monitor_rect == right.monitor_rect
}

fn previews_changed(previous: &[Window], rows: &[Window], order: &[usize]) -> bool {
    previous.len() != order.len()
        || previous
            .iter()
            .zip(order)
            .any(|(old, &index)| !same_preview(old, &rows[index]))
}

pub fn refresh(input: Refresh) -> Snapshot {
    let live: Vec<String> = input.rows.iter().map(|row| row.key.clone()).collect();
    let mut mru_keys = prune_history(&input.mru_keys, &live, 200);
    if let Some(key) = &input.active_key {
        mru_keys = note_window(&mru_keys, key, &live);
    }
    let positions: HashMap<&str, usize> = mru_keys
        .iter()
        .enumerate()
        .map(|(index, key)| (key.as_str(), index))
        .collect();
    let mut window_order: Vec<usize> = (0..input.rows.len()).collect();
    window_order.sort_by(|&left, &right| {
        match (
            positions.get(input.rows[left].key.as_str()),
            positions.get(input.rows[right].key.as_str()),
        ) {
            (Some(a), Some(b)) => a.cmp(b),
            (Some(_), None) => std::cmp::Ordering::Less,
            (None, Some(_)) => std::cmp::Ordering::Greater,
            (None, None) => input.rows[left]
                .source_index
                .total_cmp(&input.rows[right].source_index),
        }
    });
    let mut workspace_history =
        note_workspace(&input.workspace_history, input.focused_workspace_id);
    for &index in &window_order {
        if let Some(id) = input.rows[index].workspace_id {
            let key = id.to_string();
            if workspace_history.len() < 100 && !workspace_history.contains(&key) {
                workspace_history.push(key);
            }
        }
    }
    let frozen_history = if input.opening_direction.is_some() {
        if input.window_mode || input.application_mode {
            let mut seen = HashSet::new();
            window_order
                .iter()
                .filter(|&&index| {
                    eligible_target(&input.rows[index], input.overview_app.as_deref())
                })
                .map(|&index| target_key(&input.rows[index], input.application_mode))
                .filter(|key| seen.insert(key.clone()))
                .collect()
        } else {
            workspace_history.clone()
        }
    } else {
        input.frozen_history
    };
    let mut result = Snapshot {
        mru_keys,
        workspace_history,
        frozen_history,
        window_order,
        workspace_order: Vec::new(),
        groups: Vec::new(),
        selected_index: input.selected_index,
        changed: false,
    };
    if !input.opened {
        return result;
    }
    result.workspace_order = result
        .window_order
        .iter()
        .copied()
        .filter(|&index| eligible_target(&input.rows[index], input.overview_app.as_deref()))
        .collect();
    if input.window_mode || input.application_mode {
        let target_keys: Vec<String> = input
            .rows
            .iter()
            .map(|row| target_key(row, input.application_mode))
            .collect();
        // New eligible windows append without moving the frozen opening order.
        for &index in &result.workspace_order {
            let key = &target_keys[index];
            if !result.frozen_history.contains(key) {
                result.frozen_history.push(key.clone());
            }
        }
        let positions: HashMap<&str, usize> = result
            .frozen_history
            .iter()
            .enumerate()
            .map(|(index, key)| (key.as_str(), index))
            .collect();
        result
            .workspace_order
            .sort_by_key(|&index| positions[target_keys[index].as_str()]);
        for (index, &row_index) in result.workspace_order.iter().enumerate() {
            let row = &input.rows[row_index];
            let key = &target_keys[row_index];
            let label = if input.application_mode && !row.app_name.is_empty() {
                &row.app_name
            } else if input.application_mode && !row.app_id.is_empty() {
                &row.app_id
            } else if !row.title.is_empty() {
                &row.title
            } else {
                &row.app_id
            };
            if !input.application_mode || result.groups.last().is_none_or(|group| &group.key != key)
            {
                result.groups.push(Group {
                    key: key.clone(),
                    id: row.workspace_id.unwrap_or_default(),
                    label: label.chars().take(512).collect(),
                    start_index: index,
                    size: 0,
                });
            }
            if let Some(group) = result.groups.last_mut() {
                group.size += 1;
            }
        }
        result.changed = input.opening_direction.is_some()
            || if input.application_mode {
                input.previous_windows.len() != result.workspace_order.len()
                    || input
                        .previous_windows
                        .iter()
                        .zip(&result.workspace_order)
                        .any(|(old, &index)| !same_application(old, &input.rows[index]))
            } else {
                previews_changed(
                    &input.previous_windows,
                    &input.rows,
                    &result.workspace_order,
                )
            };
        let count = result.groups.len() as i32;
        let find = |key: &str| {
            result
                .groups
                .iter()
                .position(|group| group.key == key)
                .map(|index| index as i32)
        };
        result.selected_index = if count == 0 {
            -1
        } else if let Some(direction) = input.opening_direction {
            let active = input
                .active_key
                .as_deref()
                .and_then(|key| {
                    input
                        .rows
                        .iter()
                        .find(|row| row.key == key && regular_window(row))
                })
                .and_then(|row| find(&target_key(row, input.application_mode)));
            if direction == 0 {
                active.unwrap_or(0)
            } else {
                step(
                    active.unwrap_or(if direction < 0 { 0 } else { -1 }),
                    direction,
                    count,
                )
            }
        } else {
            find(&input.selected_key).unwrap_or_else(|| input.selected_index.clamp(0, count - 1))
        };
        return result;
    }
    result.workspace_order.sort_by(|&left, &right| {
        let a = &input.rows[left];
        let b = &input.rows[right];
        let position = |row: &Window| {
            result
                .frozen_history
                .iter()
                .position(|key| {
                    Some(key.as_str()) == row.workspace_id.map(|id| id.to_string()).as_deref()
                })
                .unwrap_or(result.frozen_history.len())
        };
        position(a)
            .cmp(&position(b))
            .then(a.workspace_id.cmp(&b.workspace_id))
    });
    for (index, &row_index) in result.workspace_order.iter().enumerate() {
        let row = &input.rows[row_index];
        // Filtering above establishes that every listed workspace has an id.
        let id = row.workspace_id.unwrap_or_default();
        if result.groups.last().is_none_or(|group| group.id != id) {
            let name = if row.workspace_name.is_empty() {
                id.to_string()
            } else {
                row.workspace_name.clone()
            };
            result.groups.push(Group {
                key: id.to_string(),
                id,
                label: format!("Workspace {name}"),
                start_index: index,
                size: 0,
            });
        }
        if let Some(group) = result.groups.last_mut() {
            group.size += 1;
        }
    }
    result.changed = input.opening_direction.is_some()
        || previews_changed(
            &input.previous_windows,
            &input.rows,
            &result.workspace_order,
        );
    let count = result.groups.len() as i32;
    let find = |key: &str| {
        result
            .groups
            .iter()
            .position(|group| group.key == key)
            .map(|index| index as i32)
    };
    result.selected_index = if count == 0 {
        -1
    } else if let Some(direction) = input.opening_direction {
        if direction < 0 {
            step(
                find(
                    &input
                        .focused_workspace_id
                        .map(|id| id.to_string())
                        .unwrap_or_default(),
                )
                .unwrap_or(0),
                -1,
                count,
            )
        } else if direction == 0 {
            find(
                &input
                    .focused_workspace_id
                    .map(|id| id.to_string())
                    .unwrap_or_default(),
            )
            .unwrap_or(0)
        } else {
            result
                .frozen_history
                .iter()
                .filter(|key| {
                    Some(key.as_str())
                        != input
                            .focused_workspace_id
                            .map(|id| id.to_string())
                            .as_deref()
                })
                .find_map(|key| find(key))
                .or_else(|| {
                    result
                        .groups
                        .iter()
                        .position(|group| Some(group.id) != input.focused_workspace_id)
                        .map(|index| index as i32)
                })
                .unwrap_or(0)
        }
    } else {
        find(&input.selected_key).unwrap_or_else(|| input.selected_index.clamp(0, count - 1))
    };
    result
}

#[derive(Clone, Debug, Default, Serialize, PartialEq)]
pub struct Cell {
    pub hidden: bool,
    pub x: f64,
    pub y: f64,
    pub width: f64,
    pub height: f64,
}

pub fn normalized_rect(rect: &Rect, monitor: &Rect) -> Option<Rect> {
    if !monitor.width.is_finite()
        || !monitor.height.is_finite()
        || monitor.width <= 0.0
        || monitor.height <= 0.0
        || !rect.width.is_finite()
        || !rect.height.is_finite()
        || rect.width <= 0.0
        || rect.height <= 0.0
        || !rect.x.is_finite()
        || !rect.y.is_finite()
    {
        return None;
    }
    let x = if monitor.x.is_finite() {
        monitor.x
    } else {
        0.0
    };
    let y = if monitor.y.is_finite() {
        monitor.y
    } else {
        0.0
    };
    let normalized = Rect {
        x: (rect.x - x) / monitor.width,
        y: (rect.y - y) / monitor.height,
        width: rect.width / monitor.width,
        height: rect.height / monitor.height,
    };
    [
        normalized.x,
        normalized.y,
        normalized.width,
        normalized.height,
    ]
    .iter()
    .all(|value| value.is_finite())
    .then_some(normalized)
}

pub fn layout(windows: &[Option<Window>]) -> Vec<Cell> {
    let mut cells = vec![
        Cell {
            hidden: true,
            ..Cell::default()
        };
        windows.len()
    ];
    let mut visible = Vec::new();
    let mut spatial_count = 0;
    for (index, window) in windows.iter().enumerate() {
        let Some(window) = window.as_ref().filter(|window| !window.minimized) else {
            continue;
        };
        visible.push(index);
        if let Some(rect) = window
            .rect
            .as_ref()
            .zip(window.monitor_rect.as_ref())
            .and_then(|(rect, monitor)| normalized_rect(rect, monitor))
        {
            spatial_count += 1;
            cells[index] = Cell {
                hidden: false,
                x: rect.x,
                y: rect.y,
                width: rect.width,
                height: rect.height,
            };
        }
    }
    // Keep every known native position when just one record is incomplete.
    if spatial_count > 0 || visible.is_empty() {
        return cells;
    }
    let columns = (visible.len() as f64).sqrt().ceil();
    let rows = (visible.len() as f64 / columns).ceil();
    for (position, index) in visible.into_iter().enumerate() {
        cells[index] = Cell {
            hidden: false,
            x: position as f64 % columns / columns + 0.03,
            y: (position as f64 / columns).floor() / rows + 0.03,
            width: 1.0 / columns - 0.06,
            height: 1.0 / rows - 0.06,
        };
    }
    cells
}
