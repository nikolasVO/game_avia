# Unified Aircraft Catalog

Data: `game/avia/data/aircraft/`, schema1; stable original indices0–2. 24 named fighter variants plus three retained originals. **No named fighter has completed all15 acceptance gates.** These are game balance km/h and0–100 inertia, not real performance data. [Reference audit](aircraft-sources.md).

|ID|Name|Country|State|Sea/altitude ceiling km/h|Stall/approach km/h|Inertia /100|Visual source|
|---|---|---|---|---|---|---|---|
|kite|Kite|Game Avia|flight prototype|259.2/259.2|61.2/71.4|25|procedural|
|tern|Tern|Game Avia|flight prototype|342/342|82.8/96.6|40|procedural|
|swift|Swift|Game Avia|flight prototype|522/522|115.2/134.4|55|procedural|
|f16c|F-16C Fighting Falcon|USA|flight prototype|1344/2100|220/262|35|AI candidate body; procedural gear/effects|
|su27|Su-27|Russia|flight prototype|1568/2450|240/286|64|AI candidate body; procedural gear/effects|
|f15c|F-15C Eagle|USA|flight prototype|1696/2650|250/298|70|AI candidate body; procedural gear/effects|
|su35s|Su-35S|Russia|flight prototype|1600/2500|215/256|58|AI candidate body; procedural assembly|
|rafale|Dassault Rafale C|France|flight prototype|1280/2000|205/244|45|AI candidate body; procedural assembly|
|gripen|Saab JAS 39 Gripen C|Sweden|flight prototype|1344/2100|195/232|30|AI candidate body; procedural assembly|
|f14|F-14 Tomcat|USA|planned|1568/2450|250/298|82|procedural_placeholder|
|f15e|F-15E Strike Eagle|USA|planned|1600/2500|265/315|82|procedural_placeholder|
|fa18e|F/A-18E Super Hornet|USA|planned|1216/1900|200/238|56|procedural_placeholder|
|f22|F-22 Raptor|USA|planned|1504/2350|215/256|50|procedural_placeholder|
|f35a|F-35A Lightning II|USA|planned|1216/1900|225/268|61|procedural_placeholder|
|mig21|MiG-21|Russia|planned|1408/2200|270/321|42|procedural_placeholder|
|mig29|MiG-29|Russia|planned|1536/2400|225/268|43|procedural_placeholder|
|mig31|MiG-31|Russia|planned|1920/3000|290/345|96|procedural_placeholder|
|su30sm|Su-30SM|Russia|planned|1344/2100|245/292|76|procedural_placeholder|
|su34|Su-34|Russia|planned|1216/1900|270/321|94|procedural_placeholder|
|su57|Su-57|Russia|planned|1600/2500|220/262|54|procedural_placeholder|
|typhoon|Eurofighter Typhoon|Europe|planned|1568/2450|215/256|44|procedural_placeholder|
|tornado|Panavia Tornado|Europe|planned|1472/2300|265/315|85|procedural_placeholder|
|j10c|J-10C|China|planned|1472/2300|225/268|46|procedural_placeholder|
|j20|J-20|China|planned|1472/2300|250/298|83|procedural_placeholder|
|f2|Mitsubishi F-2|Japan|planned|1344/2100|210/250|48|procedural_placeholder|
|tejas|HAL Tejas|India|planned|1216/1900|210/250|29|procedural_placeholder|
|kf21|KF-21 Boramae|South Korea|planned|1408/2200|230/274|55|procedural_placeholder|

P1 six: F-16C, Su-27, F-15C, Su-35S, Rafale C, Gripen C. Scripted force/ground/landing comparisons are separate from human flight, recognized production geometry, phone performance and public networking. The other18 are configured production backlog and are deliberately unavailable for flight.

Authored visual proportions now live in each P1 JSON: body width/height, wing chord/sweep, LERX, fin height/cant, intake layout and engine channels. These are stylized game geometry, not verified manufacturer dimensions. Gripen side intakes are separated from its single engine count. Procedural body/nozzle/channel draws share one vertex material; F16/Su27/F15C candidate+far+procedural use3. Per-LOD budgets/material counts are checked, physical-device quality remains unverified.

All six P1 bodies now have actual local TRELLIS/Blender/strict Godot validation and six separate rendered desktop clients. Su35 nozzle exits are an explicitly authored repair with cosmetic low-speed gimbals. Gripen requires full-precision mesh import to avoid two compressed LOD1 degenerates. Explicit supplied LODs are used without extra engine-generated LODs. These checks do not close the15 production gates. Android R2 remains sourcef010 with onlyF16/Su27 bodies.
