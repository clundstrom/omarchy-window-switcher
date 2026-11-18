use crate::{core::*, evaluate};
use serde_json::{Value, json};

fn strings(values: &[&str]) -> Vec<String> {
    values.iter().map(|value| (*value).to_owned()).collect()
}
fn rect(x: f64, y: f64, width: f64, height: f64) -> Rect {
    Rect {
        x,
        y,
        width,
        height,
    }
}
fn window(key: &str, workspace: i64) -> Window {
    Window {
        key: key.into(),
        source_token: format!("source:{key}"),
        workspace_id: Some(workspace),
        workspace_name: workspace.to_string(),
        monitor_id: Some(0),
        monitor_name: "test".into(),
        rect: Some(rect(12.0, 38.0, 1373.0, 1390.0)),
        monitor_rect: Some(rect(0.0, 0.0, 3440.0, 1440.0)),
        ..Window::default()
    }
}
fn opening(rows: Vec<Window>) -> Refresh {
    Refresh {
        rows,
        opened: true,
        opening_direction: Some(1),
        focused_workspace_id: Some(1),
        selected_index: -1,
        ..Refresh::default()
    }
}

#[test]
fn navigation_wraps_and_reverses() {
    assert_eq!(step(0, 1, 0), -1);
    assert_eq!(step(0, -1, 1), 0);
    for count in [1, 2, 5, 20] {
        let mut visited = std::collections::HashSet::new();
        let mut selected = 0;
        for index in 0..count {
            assert_eq!(step(step(index, 1, count), -1, count), index);
            visited.insert(selected);
            selected = step(selected, 1, count);
        }
        assert_eq!(selected, 0);
        assert_eq!(visited.len(), count as usize);
    }
    assert!((0..7).contains(&step(i32::MAX, 1, 7)));
    assert!((0..7).contains(&step(i32::MIN, -1, 7)));
}

#[test]
fn history_prunes_duplicates_dead_sources_and_respects_limits() {
    let live = strings(&["a", "b", "c", "d"]);
    assert_eq!(
        prune_history(&strings(&["d", "d", "missing", "b"]), &live, 200),
        strings(&["d", "b"])
    );
    assert_eq!(
        prune_history(&strings(&["a", "b", "c"]), &live, 2),
        strings(&["a", "b"])
    );
    assert_eq!(
        note_window(&strings(&["b", "a", "gone"]), "a", &live),
        strings(&["a", "b"])
    );
    assert_eq!(
        note_workspace(&strings(&["1", "3", "1"]), Some(3)),
        strings(&["3", "1"])
    );
    assert_eq!(
        note_workspace(&strings(&["1", "3"]), None),
        strings(&["1", "3"])
    );
}

#[test]
fn window_history_keeps_stable_source_order_for_unknown_windows() {
    let mut rows = vec![
        window("a", 1),
        window("b", 2),
        window("c", -99),
        window("d", 1),
    ];
    for (index, row) in rows.iter_mut().enumerate() {
        row.source_index = index as f64;
    }
    let mut input = opening(rows);
    input.mru_keys = strings(&["c", "a"]);
    assert_eq!(refresh(input).window_order, vec![2, 0, 1, 3]);
}

#[test]
fn opening_selects_previous_regular_workspace_and_groups_windows() {
    let mut input = opening(vec![
        window("a", 3),
        window("b", 1),
        window("c", 3),
        window("special", -99),
    ]);
    input.workspace_history = strings(&["1", "3"]);
    let result = refresh(input);
    assert_eq!(result.workspace_order, vec![1, 0, 2]);
    assert_eq!(
        result
            .groups
            .iter()
            .map(|group| (group.id, group.start_index, group.size))
            .collect::<Vec<_>>(),
        vec![(1, 0, 1), (3, 1, 2)]
    );
    assert_eq!(result.selected_index, 1);
    assert_eq!(result.frozen_history, strings(&["1", "3", "-99"]));
}

#[test]
fn reverse_opening_wraps_from_the_current_workspace() {
    let mut input = opening(vec![window("one", 1), window("two", 2), window("four", 4)]);
    input.workspace_history = strings(&["1", "4", "2"]);
    input.opening_direction = Some(-1);
    let result = refresh(input);
    assert_eq!(result.selected_index, 2);
    assert_eq!(result.groups[result.selected_index as usize].id, 2);
}

#[test]
fn excluded_workspaces_and_minimized_windows_never_become_cards() {
    let mut hidden = window("hidden", 2);
    hidden.minimized = true;
    let mut named_special = window("special-name", 4);
    named_special.workspace_name = "special:music".into();
    let mut unrelated = window("unassociated", 1);
    unrelated.workspace_id = None;
    let result = refresh(opening(vec![
        window("regular", 1),
        hidden,
        named_special,
        unrelated,
        window("negative", -99),
    ]));
    assert_eq!(result.workspace_order, vec![0]);
    assert_eq!(result.selected_index, 0);
}

#[test]
fn open_order_stays_frozen_when_focus_history_changes() {
    let rows = vec![window("one", 1), window("two", 2), window("four", 4)];
    let mut initial = opening(rows.clone());
    initial.workspace_history = strings(&["1", "4", "2"]);
    let first = refresh(initial);
    let previous = first
        .workspace_order
        .iter()
        .map(|&index| rows[index].clone())
        .collect();
    let later = refresh(Refresh {
        rows,
        previous_windows: previous,
        mru_keys: first.mru_keys,
        workspace_history: strings(&["2", "1", "4"]),
        frozen_history: first.frozen_history,
        focused_workspace_id: Some(2),
        active_key: Some("two".into()),
        opened: true,
        selected_key: "4".into(),
        selected_index: 1,
        ..Refresh::default()
    });
    assert_eq!(
        later
            .groups
            .iter()
            .map(|group| group.id)
            .collect::<Vec<_>>(),
        vec![1, 4, 2]
    );
    assert_eq!(later.selected_index, 1);
    assert!(!later.changed);
}

#[test]
fn removing_the_selected_workspace_clamps_selection_and_empty_lists_are_safe() {
    let mut input = opening(vec![window("one", 1)]);
    input.opening_direction = None;
    input.previous_windows = vec![window("one", 1), window("two", 2)];
    input.selected_key = "2".into();
    input.selected_index = 1;
    let result = refresh(input);
    assert!(result.changed);
    assert_eq!(result.selected_index, 0);
    assert_eq!(refresh(opening(vec![])).selected_index, -1);
}

#[test]
fn source_identity_changes_invalidate_previews_without_holding_window_handles() {
    let original = window("same-address", 1);
    let mut changed = original.clone();
    changed.source_token = "new-native-source".into();
    let mut input = opening(vec![changed]);
    input.opening_direction = None;
    input.previous_windows = vec![original];
    assert!(refresh(input).changed);
}

#[test]
fn focus_metadata_alone_does_not_rebuild_a_preview() {
    let original = window("one", 1);
    let mut changed = original.clone();
    changed.source_index = 7.0;
    let mut input = opening(vec![changed]);
    input.opening_direction = None;
    input.previous_windows = vec![original];
    assert!(!refresh(input).changed);
}

#[test]
fn geometry_and_label_changes_invalidate_stale_previews() {
    let original = window("one", 1);
    for changed in [
        Window {
            workspace_name: "Development".into(),
            ..original.clone()
        },
        Window {
            rect: Some(rect(-320.0, 38.0, 640.0, 1390.0)),
            ..original.clone()
        },
        Window {
            monitor_rect: Some(rect(1920.0, 0.0, 2560.0, 1440.0)),
            ..original.clone()
        },
        Window {
            rect: None,
            ..original.clone()
        },
        Window {
            monitor_rect: None,
            ..original.clone()
        },
    ] {
        let mut input = opening(vec![changed]);
        input.opening_direction = None;
        input.previous_windows = vec![original.clone()];
        assert!(refresh(input).changed);
    }
}

#[test]
fn three_unequal_columns_keep_their_native_positions() {
    let base = window("one", 3);
    let windows = [
        rect(12.0, 38.0, 1373.0, 1390.0),
        rect(1399.0, 38.0, 1005.0, 1390.0),
        rect(2418.0, 38.0, 1010.0, 1390.0),
    ]
    .into_iter()
    .map(|rect| {
        Some(Window {
            rect: Some(rect),
            ..base.clone()
        })
    })
    .collect::<Vec<_>>();
    let result = layout(&windows);
    assert_eq!(
        result.iter().map(|cell| cell.x).collect::<Vec<_>>(),
        vec![12.0 / 3440.0, 1399.0 / 3440.0, 2418.0 / 3440.0]
    );
    assert_eq!(
        result.iter().map(|cell| cell.width).collect::<Vec<_>>(),
        vec![1373.0 / 3440.0, 1005.0 / 3440.0, 1010.0 / 3440.0]
    );
    assert!(
        result
            .iter()
            .all(|cell| !cell.hidden && cell.height == 1390.0 / 1440.0)
    );
}

#[test]
fn floating_and_scrolling_geometry_is_clipped_by_the_interface_not_rearranged() {
    let monitor = rect(0.0, 0.0, 3440.0, 1440.0);
    assert_eq!(
        normalized_rect(&rect(-500.0, -100.0, 5000.0, 2000.0), &monitor),
        Some(rect(
            -500.0 / 3440.0,
            -100.0 / 1440.0,
            5000.0 / 3440.0,
            2000.0 / 1440.0
        ))
    );
    let floating = normalized_rect(&rect(800.0, 300.0, 900.0, 500.0), &monitor).unwrap();
    assert_eq!(floating.x, 800.0 / 3440.0);
    assert_eq!(floating.y, 300.0 / 1440.0);
    assert_eq!(
        normalized_rect(
            &rect(3700.0, 300.0, 960.0, 540.0),
            &rect(3440.0, 120.0, 1920.0, 1080.0)
        ),
        Some(rect(260.0 / 1920.0, 180.0 / 1080.0, 0.5, 0.5))
    );
}

#[test]
fn incomplete_or_destroyed_records_do_not_rearrange_valid_windows() {
    let first = window("one", 1);
    let incomplete = Window {
        rect: None,
        ..first.clone()
    };
    let hidden = Window {
        minimized: true,
        ..first.clone()
    };
    let result = layout(&[Some(first), Some(incomplete), None, Some(hidden)]);
    assert_eq!(result[0].x, 12.0 / 3440.0);
    assert_eq!(
        result
            .iter()
            .skip(1)
            .map(|cell| cell.hidden)
            .collect::<Vec<_>>(),
        vec![true, true, true]
    );
    assert!(layout(&[]).is_empty());
    assert!(layout(&[None])[0].hidden);
    let fallback = layout(&[Some(Window::default()), Some(Window::default())]);
    assert!(fallback.iter().all(|cell| !cell.hidden && cell.width > 0.0));
    assert!(fallback[1].x > fallback[0].x);
}

#[test]
fn invalid_geometry_is_not_rendered() {
    let monitor = rect(0.0, 0.0, 3440.0, 1440.0);
    for bad in [
        rect(0.0, 0.0, 0.0, 1.0),
        rect(f64::NAN, 0.0, 1.0, 1.0),
        rect(0.0, 0.0, f64::INFINITY, 1.0),
    ] {
        assert!(normalized_rect(&bad, &monitor).is_none());
    }
    assert!(
        normalized_rect(
            &rect(0.0, 0.0, 1.0, 1.0),
            &rect(0.0, 0.0, f64::INFINITY, 1440.0)
        )
        .is_none()
    );
}

#[test]
fn native_boundary_rejects_malformed_and_excessive_data() {
    for (operation, input) in [("refresh", "{"), ("layout", "{}"), ("unknown", "{}")] {
        let result: Value = serde_json::from_str(&evaluate(operation, input)).unwrap();
        assert!(result.get("error").is_some());
    }
    let result: Value = serde_json::from_str(&evaluate("refresh", &" ".repeat(1_048_577))).unwrap();
    assert!(result.get("error").is_some());
    assert_eq!(
        serde_json::from_str::<Value>(&evaluate(
            "workspaceFocus",
            &json!({"keys":["1","3"],"workspaceId":3}).to_string()
        ))
        .unwrap(),
        json!(["3", "1"])
    );
}
