#pragma once

#include <QObject>
#include <QVariantList>
#include <QtQml/qqml.h>

class QOscClient;

class OscClient : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString host READ host WRITE setHost NOTIFY hostChanged)
    Q_PROPERTY(int port READ port WRITE setPort NOTIFY portChanged)

public:
    explicit OscClient(QObject *parent = nullptr);
    ~OscClient() override;

    QString host() const { return m_host; }
    int port() const { return m_port; }

    void setHost(const QString &host);
    void setPort(int port);

    Q_INVOKABLE void sendMessage(const QString &path, const QVariantList &args);

signals:
    void hostChanged();
    void portChanged();

private:
    void recreateClient();

    QString m_host;
    int m_port;
    QOscClient *m_client = nullptr;
};
