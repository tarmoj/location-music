#pragma once

#include <QObject>
#include <QtQml/qqml.h>

class NetworkInfo : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString localIp READ localIp CONSTANT)

public:
    explicit NetworkInfo(QObject *parent = nullptr);

    QString localIp() const;

private:
    QString m_localIp;
};
