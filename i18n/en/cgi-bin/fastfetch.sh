#!/bin/bash
echo "Content-type: text/html"
echo
export PATH=/usr/local/bin:/usr/bin:/bin
FASTFETCH_BIN=$(command -v fastfetch 2>/dev/null)
clean_output() { sed -e 's/\x1b\[[0-9;]*[a-zA-Z]//g' -e 's/\x1b\[?[0-9;]*[a-z]//g'; }

if [[ -x "$FASTFETCH_BIN" ]]; then
    SYSINFO=$($FASTFETCH_BIN --logo none --structure os:host:kernel:cpu:gpu:memory:swap:disk:localip 2>&1)
    SYSINFO_CLEAN=$(echo "$SYSINFO" | clean_output)
else
    SYSINFO_CLEAN="Fastfetch not found"
fi

cat <<'HTMLEOF'
<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<style>
*{box-sizing:border-box;margin:0;padding:0}
html,body{background:transparent;color:#c9d1d9;font-family:'SFMono-Regular',Consolas,'Liberation Mono',Menlo,monospace}
body{padding:8px;display:flex;justify-content:center}
.t{display:flex;width:100%;max-width:860px;background:#0a0e14;border-radius:8px;overflow:hidden;box-shadow:0 5px 16px rgba(0,0,0,.5)}
.lp{padding:22px 16px;display:flex;align-items:center;justify-content:center;border-right:1px solid #30363d;flex-shrink:0}
.logo{font-size:11.5px;line-height:1.12;white-space:pre;color:#fff;font-family:'Courier New',Courier,monospace}
.ip{padding:16px;flex:1;min-width:0;background:#0c1015;display:flex;flex-direction:column;align-items:center;justify-content:center}
.hdr{text-align:center;margin-bottom:12px;padding-bottom:9px;border-bottom:1px solid #30363d;width:100%}
.ti{color:#268bd2;font-size:20px;font-weight:bold}
.st{color:#859900;font-size:13px;margin-top:2px}
.bdg{background:#002b36;border:1px solid #073642;padding:4px 9px;border-radius:5px;margin-top:6px;display:inline-block;font-size:10px;color:#c9d1d9}
.g{display:grid;grid-template-columns:auto 1fr;gap:4px 12px;font-size:13px;width:100%;max-width:420px}
.l{color:#859900;text-align:right;font-weight:bold;white-space:nowrap}
.v{color:#fff;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
@media(max-width:800px){
  .lp{display:none}
  body{padding:4px}
  .ip{padding:12px}
  .ti{font-size:17px}
  .st{font-size:11px}
  .bdg{font-size:9px}
  .g{font-size:12px;gap:3px 10px}
  .hdr{margin-bottom:10px;padding-bottom:7px}
}
@media(max-width:500px){
  .ip{padding:8px}
  .ti{font-size:14px}
  .st{font-size:10px}
  .bdg{font-size:8px;padding:3px 6px}
  .g{font-size:10.5px;gap:2px 6px}
  .v{white-space:normal;word-break:break-word}
  .hdr{margin-bottom:8px;padding-bottom:6px}
}
</style></head><body>
<div class="t" id="root">
  <div class="lp"><div class="logo">&#96;.::///+:/-.        --///+//-:&#96;
 &#96;+oooooooooooo:   &#96;+oooooooooooo:
  /oooo++//ooooo:  ooooo+//+ooooo.
  &#96;+ooooooo:-:oo-  +o+::/ooooooo:
   &#96;:oooooooo+&#96;&#96;    &#96;.oooooooo+-
     &#96;:++ooo/.        :+ooo+/.&#96;
        ...&#96;  &#96;.----.&#96; &#96;&#96;..
     .::::-&#96;&#96;:::::::::.&#96;-:::-&#96;
    -:::-&#96;   .:::::::-&#96;  &#96;-:::-
   &#96;::.  &#96;.--.&#96;  &#96;&#96; &#96;.---.&#96;&#96;.::&#96;
       .::::::::&#96;  -::::::::&#96; &#96;
 .::&#96; .:::::::::- &#96;::::::::::&#96;&#96;::.
-:::&#96; ::::::::::.  ::::::::::.&#96;:::-
::::  -::::::::.   &#96;-::::::::  ::::
-::-   .-:::-.&#96;&#96;....&#96;&#96;.-::-.   -::-
 .. &#96;&#96;       .::::::::.     &#96;..&#96;..
   -:::-&#96;   -::::::::::&#96;  .::::&#96;
   :::::::&#96; -::::::::::&#96; :::::::.
   .:::::::  -::::::::. ::::::::
    &#96;-:::::&#96;   ..--.&#96;   ::::::.
      &#96;...&#96;  &#96;...--..&#96;  &#96;...&#96;
            .::::::::::
             &#96;.-::::-&#96;</div></div>
  <div class="ip">
    <div class="hdr">
      <div class="ti">Pi-Router</div>
      <div class="st">Raspberry Pi 5 - Debian 13</div>
      <div class="bdg">System Pi-Dock-Wifi Router Status</div>
    </div>
    <div class="g">
HTMLEOF

if [[ "$SYSINFO_CLEAN" == "Fastfetch not found" ]]; then
    echo "<div class='l'>Error:</div><div class='v'>Fastfetch not installed</div>"
else
    echo "<div class='l'>OS:</div><div class='v'>$(echo "$SYSINFO_CLEAN" | awk -F': ' '/OS:/ {print $2}')</div>"
    echo "<div class='l'>Host:</div><div class='v'>$(echo "$SYSINFO_CLEAN" | awk -F': ' '/Host:/ {print $2}')</div>"
    echo "<div class='l'>Kernel:</div><div class='v'>$(echo "$SYSINFO_CLEAN" | awk -F': ' '/Kernel:/ {print $2}')</div>"
    echo "<div class='l'>CPU:</div><div class='v'>$(echo "$SYSINFO_CLEAN" | awk -F': ' '/CPU:/ {print $2}')</div>"
    echo "<div class='l'>GPU:</div><div class='v'>$(echo "$SYSINFO_CLEAN" | awk -F': ' '/GPU:/ {print $2}')</div>"
    echo "<div class='l'>Memory:</div><div class='v'>$(echo "$SYSINFO_CLEAN" | awk -F': ' '/Memory:/ {print $2}')</div>"
    echo "<div class='l'>Swap:</div><div class='v'>$(echo "$SYSINFO_CLEAN" | awk -F': ' '/Swap:/ {print $2}')</div>"
    echo "<div class='l'>Disk (/):</div><div class='v'>$(echo "$SYSINFO_CLEAN" | awk -F': ' '/Disk \(\/\):/ {print $2}')</div>"
    echo "<div class='l'>Local IP:</div><div class='v'>$(echo "$SYSINFO_CLEAN" | awk -F': ' '/Local IP/ {print $2}')</div>"
fi

cat <<'HTMLEOF'
    </div>
  </div>
</div>
<script>
function sh(){var h=document.getElementById('root').offsetHeight+16;try{parent.postMessage({type:'fastfetch-height',height:h},'*')}catch(e){}}
sh();window.onresize=sh;setTimeout(sh,500);setTimeout(sh,1500);
</script>
</body></html>
HTMLEOF
