#include "networkinfo.h"
#include <QNetworkInterface>
#include <QHostAddress>
#include <QAbstractSocket>

NetworkInfo::NetworkInfo(QObject *parent)
    : QObject(parent)
{
    const auto interfaces = QNetworkInterface::allInterfaces();
    for (const QNetworkInterface &iface : interfaces) {
        if (!(iface.flags() & QNetworkInterface::IsUp) ||
            !(iface.flags() & QNetworkInterface::IsRunning))
            continue;
        if (iface.flags() & QNetworkInterface::IsLoopBack)
            continue;

        for (const QNetworkAddressEntry &entry : iface.addressEntries()) {
            const QHostAddress addr = entry.ip();
            if (addr.protocol() == QAbstractSocket::IPv4Protocol) {
                m_localIp = addr.toString();
                return;
            }
        }
    }

    m_localIp = QStringLiteral("127.0.0.1");
}

QString NetworkInfo::localIp() const
{
    return m_localIp;
}
