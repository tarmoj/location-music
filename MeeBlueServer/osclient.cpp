#include "osclient.h"
#include "qosc/qoscclient.h"

#include <QHostAddress>

OscClient::OscClient(QObject *parent)
    : QObject(parent)
    , m_host(QStringLiteral("127.0.0.1"))
    , m_port(9000)
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
    // QML passes JS numbers as QVariant(double). QOsc only produces 'i'
    // for QMetaType::Int, so coerce whole-number doubles to int.
    QVariantList coerced;
    coerced.reserve(args.size());
    for (const QVariant &v : args) {
        if (v.typeId() == QMetaType::Double) {
            double d = v.toDouble();
            if (d == std::floor(d))
                coerced.append(QVariant(static_cast<int>(d)));
            else
                coerced.append(v);
        } else {
            coerced.append(v);
        }
    }
    m_client->sendData(path, coerced);
}

void OscClient::recreateClient()
{
    delete m_client;
    m_client = new QOscClient(QHostAddress(m_host), static_cast<quint16>(m_port), this);
    qDebug() << "Created OSC client with host:" << m_host << "and port:" << m_port;
}
