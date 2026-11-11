#include "osclient.h"
#include "qosc/qoscclient.h"

#include <QHostAddress>

OscClient::OscClient(QObject *parent)
    : QObject(parent)
    , m_host(QStringLiteral("127.0.0.1"))
    , m_port(8000)
{
    recreateClient();
}

OscClient::~OscClient() = default;

void OscClient::setHost(const QString &host)
{
    if (m_host == host)
        return;
    m_host = host;
    emit hostChanged();
    recreateClient();
}

void OscClient::setPort(int port)
{
    if (m_port == port)
        return;
    m_port = port;
    emit portChanged();
    recreateClient();
}

void OscClient::sendMessage(const QString &path, const QVariantList &args)
{
    if (!m_client)
        return;

    QVariantList floatArgs;
    floatArgs.reserve(args.size());
    for (const QVariant &arg : args) {
        switch (arg.typeId()) {
        case QMetaType::Char:
        case QMetaType::SChar:
        case QMetaType::UChar:
        case QMetaType::Short:
        case QMetaType::UShort:
        case QMetaType::Int:
        case QMetaType::UInt:
        case QMetaType::Long:
        case QMetaType::ULong:
        case QMetaType::LongLong:
        case QMetaType::ULongLong:
        case QMetaType::Float:
            floatArgs.append(arg.toDouble());
            break;
        default:
            floatArgs.append(arg);
            break;
        }
    }

    m_client->sendData(path, floatArgs);
}

void OscClient::recreateClient()
{
    delete m_client;
    m_client = new QOscClient(QHostAddress(m_host), static_cast<quint16>(m_port), this);
    qDebug() << "Created OSC client with host:" << m_host << "and port:" << m_port;
}
