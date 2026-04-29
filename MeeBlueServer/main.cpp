#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    app.setOrganizationName("Tarmo Johannes Events and Software");
    app.setOrganizationDomain("meeblue-server.org");
    app.setApplicationName("MeeBlue Server");

#if defined(Q_OS_LINUX)
    app.setWindowIcon(QIcon(":/images/M.png"));
#endif

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("MeeBlueServer", "Main");

    return app.exec();
}
