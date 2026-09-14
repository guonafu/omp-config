#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "ompconfigbackend.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    QGuiApplication::setApplicationName(QStringLiteral("omp-config"));
    QGuiApplication::setOrganizationName(QStringLiteral("omp"));

    OmpConfigBackend backend;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("ompBackend", &backend);
    engine.loadFromModule("ompconfig", "Main");
    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}