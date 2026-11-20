import QtQml
import Quickshell

// Only resolves metadata for apps that own eligible windows. No launcher list
// or file scan is performed by this component; Quickshell owns the shared index.
QtObject {
  id: metadata
  property bool enabled: false
  property var aliases: ({})
  property var cache: ({})
  signal refreshed()
  onAliasesChanged: { cache = ({}); refreshed() }

  function desktopIdFor(appId) {
    if (!aliases || typeof aliases !== "object" || Array.isArray(aliases)
        || !Object.prototype.hasOwnProperty.call(aliases, appId)) return appId
    var value = aliases[appId]
    if (typeof value !== "string" || value.length > 256
        || !/^[A-Za-z0-9_+-][A-Za-z0-9_.+-]*$/.test(value)) return appId
    return value.replace(/\.desktop$/, "")
  }

  function iconSource(value) {
    var icon = String(value || "")
    if (icon.length > 2048) icon = ""
    if (icon.charAt(0) === "/" && icon.charAt(1) !== "/") {
      return "file://" + icon.split("/").map(encodeURIComponent).join("/")
    }
    if (!/^[A-Za-z0-9_.+-]+$/.test(icon)) icon = "application-x-executable"
    return Quickshell.iconPath(icon, "application-x-executable")
  }
  function lookup(appId) {
    if (!enabled || !appId) return ({})
    return resolve(appId)
  }
  // Explicit overview invocation may resolve its origin before preview mode
  // enables the provider. Ordinary preview enumeration still calls lookup.
  function resolve(appId) {
    if (!appId) return ({})
    var key = "app:" + appId
    if (cache[key] !== undefined) return cache[key]
    var id = desktopIdFor(appId)
    var entry = DesktopEntries.heuristicLookup(id)
    if (!entry && id !== appId) entry = DesktopEntries.heuristicLookup(appId)
    var result = {
      id: entry ? String(entry.id) : appId,
      name: entry ? String(entry.name) : appId,
      icon: iconSource(entry ? entry.icon : appId)
    }
    if (Object.keys(cache).length >= 128) cache = ({})
    cache[key] = result
    return result
  }
  property Connections entryChanges: Connections {
    target: metadata.enabled ? DesktopEntries : null
    function onApplicationsChanged() { metadata.cache = ({}); metadata.refreshed() }
  }
}
