#include <QQmlExtensionPlugin>
#include <QtQml>
#include "workspace-switcher-native/src/lib.rs.h"

// Window objects stay in QML. Only plain data crosses the generated Rust bridge.
class WorkspaceCore : public QObject {
    Q_OBJECT
public:
    using QObject::QObject;
    Q_INVOKABLE QString evaluate(const QString &operation, const QString &input) const {
        const auto op = operation.toUtf8();
        const auto data = input.toUtf8();
        const auto result = workspace_switcher::evaluate(
            rust::Str(op.constData(), op.size()), rust::Str(data.constData(), data.size()));
        return QString::fromUtf8(result.data(), result.size());
    }
    Q_INVOKABLE int step(int index, int direction, int count) const {
        return workspace_switcher::step(index, direction, count);
    }
};

class WorkspacePlugin : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)
public:
    void registerTypes(const char *uri) override {
        qmlRegisterType<WorkspaceCore>(uri, 1, 0, "WorkspaceCore");
    }
};
#include "coreplugin.moc"
