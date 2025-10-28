import asyncio
from bleak import BleakScanner
import math

# === CONFIG ===
TARGET_ADDR = "DD:2B:7C:C0:A0:84"   # your beacon’s MAC address
TARGET_NAME = "meeblue-PA"          # optional, use if address changes
TX_POWER = -40  # typical measured power (RSSI at 1 meter)
N = 2.0         # environmental factor (1.6–3.0; higher = more walls/interference)

# === STATE ===
latest_rssi = None

def estimate_distance(rssi, tx_power=TX_POWER, n=N):
    """Estimate distance (in meters) from RSSI using log-distance path loss model."""
    if rssi == 0:
        return None
    ratio = (tx_power - rssi) / (10 * n)
    return round(10 ** ratio, 2)

def detection_callback(device, adv_data):
    #print(f"Discovered device: {device}, adv_data: {adv_data} ")
    global latest_rssi
    if (device.address == TARGET_ADDR) or (device.name == TARGET_NAME):
        latest_rssi = adv_data.rssi
        distance = estimate_distance(latest_rssi)
        print(f"{device.name} ({device.address}): RSSI={latest_rssi} dBm → Distance ≈ {distance} m")

async def track_beacon():
    print("Starting continuous scan… (press Ctrl+C to stop)")
    scanner = BleakScanner(detection_callback)
    await scanner.start()
    try:
        while True:
            await asyncio.sleep(0.5)
    except KeyboardInterrupt:
        print("\nStopping scan…")
    finally:
        await scanner.stop()

if __name__ == "__main__":
    asyncio.run(track_beacon())
