#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QIcon>
#include <QCoreApplication>

#include "ompconfigbackend.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("omp-config"));
    QGuiApplication::setOrganizationName(QStringLiteral("omp"));
    app.setWindowIcon(QIcon(QStringLiteral(":/icons/pi.png")));

    OmpConfigBackend backend;

    QQmlApplicationEngine engine;
    // 安装版: /usr/lib/omp-config/qml (含 ompconfig 模块)
    engine.addImportPath(QCoreApplication::applicationDirPath() + QStringLiteral("/../lib/omp-config/qml"));
    engine.rootContext()->setContextProperty("ompBackend", &backend);
    engine.loadFromModule("ompconfig", "Main");
    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}