#include "recorder.h"

#include <QFile>
#include <QDataStream>
#include <QFileInfo>

Recorder::Recorder(QObject *parent)
    : QObject(parent)
{
    m_timer.setInterval(kSampleIntervalMs);
    connect(&m_timer, &QTimer::timeout, this, &Recorder::onTimerTick);
}

int Recorder::elapsedMs() const
{
    if (m_recording)
        return m_samples.size() * static_cast<int>(kSampleIntervalMs);
    return m_playIndex * static_cast<int>(kSampleIntervalMs);
}

int Recorder::durationMs() const
{
    if (m_hasFile && !m_recording)
        return m_samples.size() * static_cast<int>(kSampleIntervalMs);
    return 0;
}

void Recorder::setRecording(bool v)
{
    if (m_recording == v)
        return;
    m_recording = v;
    emit recordingChanged();
}

void Recorder::setPlaying(bool v)
{
    if (m_playing == v)
        return;
    m_playing = v;
    emit playingChanged();
}

void Recorder::startRecording(const QStringList &stationIds)
{
    if (m_playing) {
        emit errorOccurred(QStringLiteral("Cannot start recording while playing back."));
        return;
    }

    m_timer.stop();
    m_samples.clear();
    m_stationIds = stationIds;
    m_hasFile = false;
    m_fileName.clear();
    m_playIndex = 0;

    emit stationIdsChanged();
    emit hasFileChanged();
    emit fileNameChanged();
    emit durationMsChanged();
    emit elapsedMsChanged();

    setRecording(true);
    m_timer.start();
}

void Recorder::appendSample(const QVariantList &values)
{
    QVector<float> record;
    record.reserve(values.size());
    for (const QVariant &v : values)
        record.append(v.toFloat());
    m_samples.append(record);
    emit elapsedMsChanged();
}

void Recorder::stopRecording()
{
    if (!m_recording)
        return;
    m_timer.stop();
    setRecording(false);
}

bool Recorder::saveRecording(const QUrl &fileUrl)
{
    const QString path = fileUrl.toLocalFile();
    if (path.isEmpty()) {
        emit errorOccurred(QStringLiteral("Invalid save location."));
        return false;
    }

    QFile file(path);
    if (!file.open(QIODevice::WriteOnly)) {
        emit errorOccurred(QStringLiteral("Could not open file for writing: %1").arg(path));
        return false;
    }

    QDataStream out(&file);
    out.setVersion(QDataStream::Qt_6_0);
    out.setFloatingPointPrecision(QDataStream::SinglePrecision);

    out << kMagic << kFormatVersion << kSampleIntervalMs
        << static_cast<quint32>(m_stationIds.size()) << m_stationIds;

    for (const QVector<float> &record : m_samples) {
        for (float value : record)
            out << value;
    }

    file.close();

    m_fileName = QFileInfo(path).fileName();
    m_hasFile = true;
    emit fileNameChanged();
    emit hasFileChanged();
    emit durationMsChanged();
    return true;
}

bool Recorder::loadFile(const QUrl &fileUrl)
{
    const QString path = fileUrl.toLocalFile();
    if (path.isEmpty()) {
        emit errorOccurred(QStringLiteral("Invalid file location."));
        return false;
    }

    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        emit errorOccurred(QStringLiteral("Could not open file for reading: %1").arg(path));
        return false;
    }

    QDataStream in(&file);
    in.setVersion(QDataStream::Qt_6_0);
    in.setFloatingPointPrecision(QDataStream::SinglePrecision);

    quint32 magic = 0, formatVersion = 0, sampleIntervalMs = 0, stationCount = 0;
    in >> magic >> formatVersion >> sampleIntervalMs >> stationCount;

    if (magic != kMagic || formatVersion != kFormatVersion) {
        emit errorOccurred(QStringLiteral("Not a valid MeeBlue recording file: %1").arg(path));
        return false;
    }

    QStringList stationIds;
    in >> stationIds;

    if (in.status() != QDataStream::Ok || static_cast<quint32>(stationIds.size()) != stationCount) {
        emit errorOccurred(QStringLiteral("Corrupt recording file header: %1").arg(path));
        return false;
    }

    QVector<QVector<float>> samples;
    while (!in.atEnd()) {
        QVector<float> record;
        record.reserve(stationCount);
        for (quint32 i = 0; i < stationCount; ++i) {
            float value = 0.0f;
            in >> value;
            if (in.status() != QDataStream::Ok) {
                // Truncated trailing record: stop, keep what was fully read.
                record.clear();
                break;
            }
            record.append(value);
        }
        if (record.size() != static_cast<int>(stationCount))
            break;
        samples.append(record);
    }

    m_timer.stop();
    setPlaying(false);
    setRecording(false);

    m_stationIds = stationIds;
    m_samples = samples;
    m_playIndex = 0;
    m_hasFile = true;
    m_fileName = QFileInfo(path).fileName();

    emit stationIdsChanged();
    emit fileNameChanged();
    emit hasFileChanged();
    emit durationMsChanged();
    emit elapsedMsChanged();
    return true;
}

void Recorder::play()
{
    if (m_recording) {
        emit errorOccurred(QStringLiteral("Cannot play back while recording."));
        return;
    }
    if (!m_hasFile || m_samples.isEmpty()) {
        emit errorOccurred(QStringLiteral("No recording loaded to play."));
        return;
    }

    if (m_playIndex >= m_samples.size())
        m_playIndex = 0;

    setPlaying(true);
    m_timer.start();
}

void Recorder::pause()
{
    if (!m_playing)
        return;
    m_timer.stop();
    setPlaying(false);
}

void Recorder::stop()
{
    m_timer.stop();
    setPlaying(false);
    m_playIndex = 0;
    emit elapsedMsChanged();
}

void Recorder::seek(int ms)
{
    if (m_samples.isEmpty())
        return;

    const int clampedMs = qBound(0, ms, durationMs());
    m_playIndex = qBound(0, clampedMs / static_cast<int>(kSampleIntervalMs), m_samples.size() - 1);
    emit elapsedMsChanged();

    QVariantList values;
    values.reserve(m_samples[m_playIndex].size());
    for (float v : m_samples[m_playIndex])
        values.append(v);
    emit sampleReady(values);
}

void Recorder::onTimerTick()
{
    if (m_recording) {
        emit captureRequested();
        return;
    }

    if (!m_playing)
        return;

    QVariantList values;
    values.reserve(m_samples[m_playIndex].size());
    for (float v : m_samples[m_playIndex])
        values.append(v);
    emit sampleReady(values);

    ++m_playIndex;
    emit elapsedMsChanged();

    if (m_playIndex >= m_samples.size()) {
        m_timer.stop();
        setPlaying(false);
        emit playbackFinished();
    }
}
