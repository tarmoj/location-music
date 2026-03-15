from bleak import BleakScanner

def parse_meeblue_data(advertisement_data):
    print("Advertisement Data:", advertisement_data)
    if advertisement_data is None:
        return
    # advertisement_data may be an AdvertisementData object (has .manufacturer_data)
    # or a plain dict stored in metadata. Handle both.
    if hasattr(advertisement_data, "manufacturer_data"):
        mdata = advertisement_data.manufacturer_data
    elif isinstance(advertisement_data, dict):
        # some versions place manufacturer_data directly in the dict
        mdata = advertisement_data.get("manufacturer_data") or advertisement_data
    else:
        mdata = None

    if not mdata:
        return

    for key, value in mdata.items():
        if isinstance(value, (bytes, bytearray)):
            hexstr = value.hex()
        else:
            try:
                hexstr = bytes(value).hex()
            except Exception:
                hexstr = str(value)
        print(f"Manufacturer {key}: {hexstr}")

async def main():
    devices = await BleakScanner.discover()
    for d in devices:
        if "meeblue" in (d.name or "").lower():
            # Robust RSSI lookup across bleak versions/backends
            rssi = getattr(d, "rssi", None)
            md = getattr(d, "metadata", {}) or {}

            # advertisement_data may be stored in metadata under 'advertisement_data'
            adv = None
            if isinstance(md, dict):
                adv = md.get("advertisement_data")
                # some versions put rssi into metadata
                if rssi is None:
                    rssi = md.get("rssi")

            # AdvertisementData object itself may contain rssi
            if adv and getattr(adv, "rssi", None) is not None:
                rssi = adv.rssi

            print(f"Found M52 beacon: {d.address}, RSSI={rssi} dBm")
            # Prefer advertisement_data object, fallback to metadata manufacturer_data
            parse_meeblue_data(adv or md.get("manufacturer_data") or md.get("manufacturer data"))

import asyncio
asyncio.run(main())

