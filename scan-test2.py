import asyncio

from bleak import BleakScanner

async def scan_devices():
    devices = await BleakScanner.discover(return_adv=True)
    for dev, (device, adv_data) in devices.items():
        name = (device.name or getattr(adv_data, "local_name", "") or "").lower()
        #print(f"Device: {device}, data: {adv_data}")
        if name.startswith("meeblue"):
            print(f"Device: {device.address}, {device.name}, RSSI: {adv_data.rssi} dBm")

# address: DD:2B:7C:C0:A0:84
# adv_data:  (BLEDevice(DD:2B:7C:C0:A0:84, meeblue-PA), AdvertisementData(local_name='meeblue-PA', manufacturer_data={76: b'\x02\x15\xd3[v\xe2\xe0\x1c\x9f\xac\xba\x8d|\xe2\x0b\xdb\xa0\xc6\x84\xa0\xc0|\xcb'}, service_data={'00005000-0000-1000-8000-00805f9b34fb': b'\xdd+|\xc0\xa0\x84\xf5\x0b'}, service_uuids=['00002000-0000-1000-8000-00805f9b34fb', '00005000-0000-1000-8000-00805f9b34fb'], tx_power=0, rssi=-39))
# Run the scan
import asyncio
asyncio.run(scan_devices())
