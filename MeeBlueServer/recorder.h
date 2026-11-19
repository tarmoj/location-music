#pragma once

#include <QObject>
#include <QtQml/qqml.h>
#include <QVariantList>
#include <QStringList>
#include <QVector>
#include <QTimer>
#include <QUrl>
#include <QString>

class Recorder : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool recording READ recording NOTIFY recordingChanged)
    Q_PROPERTY(bool playing READ playing NOTIFY playingChanged)
    Q_PROPERTY(bool hasFile READ hasFile NOTIFY hasFileChanged)
    Q_PROPERTY(QString fileName READ fileName NOTIFY fileNameChanged)
    Q_PROPERTY(int elapsedMs READ elapsedMs NOTIFY elapsedMsChanged)
    Q_PROPERTY(int durationMs READ durationMs NOTIFY durationMsChanged)
    Q_PROPERTY(QStringList stationIds READ stationIds NOTIFY stationIdsChanged)

public:
    explicit Recorder(QObject *parent = nullptr);

    bool recording() const { return m_recording; }
    bool playing() const { return m_playing; }
    bool hasFile() const { return m_hasFile; }
    QString fileName() const { return m_fileName; }
    int elapsedMs() const;
    int durationMs() const;
    QStringList stationIds() const { return m_stationIds; }

    Q_INVOKABLE void startRecording(const QStringList &stationIds);
    Q_INVOKABLE void appendSample(const QVariantList &values);
    Q_INVOKABLE void stopRecording();
    Q_INVOKABLE bool saveRecording(const QUrl &fileUrl);

    Q_INVOKABLE bool loadFile(const QUrl &fileUrl);
    Q_INVOKABLE void play();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void seek(int ms);

signals:
    void recordingChanged();
    void playingChanged();
    void hasFileChanged();
    void fileNameChanged();
    void elapsedMsChanged();
    void durationMsChanged();
    void stationIdsChanged();

    void captureRequested();                     // tick while recording
    void sampleReady(const QVariantList &values); // tick while playing/seeking
    void playbackFinished();
    void errorOccurred(const QString &message);

private:
    void onTimerTick();
    void setRecording(bool v);
    void setPlaying(bool v);

    static constexpr quint32 kSampleIntervalMs = 250;
    static constexpr quint32 kMagic = 0x4D545243; // "MTRC"
    static constexpr quint32 kFormatVersion = 1;

    QTimer m_timer;
    bool m_recording = false;
    bool m_playing = false;
    bool m_hasFile = false;
    QString m_fileName;
    QStringList m_stationIds;

    // Recording buffer / loaded-file samples: one entry per 250ms tick,
    // each sized m_stationIds.count().
    QVector<QVector<float>> m_samples;

    int m_playIndex = 0;
};
