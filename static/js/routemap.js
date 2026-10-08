(function () {
  function toRad(d) {
    return (d * Math.PI) / 180;
  }

  function toDeg(r) {
    return (r * 180) / Math.PI;
  }

  function gcNm(a, b) {
    var R = 3440.065;
    var p1 = toRad(a[0]);
    var p2 = toRad(b[0]);
    var dphi = toRad(b[0] - a[0]);
    var dl = toRad(b[1] - a[1]);
    var h =
      Math.sin(dphi / 2) * Math.sin(dphi / 2) +
      Math.cos(p1) * Math.cos(p2) * Math.sin(dl / 2) * Math.sin(dl / 2);
    return 2 * R * Math.asin(Math.min(1, Math.sqrt(h)));
  }

  function gcSegment(a, b) {
    var lat1 = toRad(a[0]);
    var lon1 = toRad(a[1]);
    var lat2 = toRad(b[0]);
    var lon2 = toRad(b[1]);
    var d = 2 * Math.asin(
      Math.sqrt(
        Math.pow(Math.sin((lat2 - lat1) / 2), 2) +
          Math.cos(lat1) * Math.cos(lat2) * Math.pow(Math.sin((lon2 - lon1) / 2), 2)
      )
    );
    if (d < 1e-8) return [a, b];
    var n = Math.max(2, Math.ceil(gcNm(a, b) / 40));
    var pts = [];
    for (var i = 0; i <= n; i++) {
      var f = i / n;
      var A = Math.sin((1 - f) * d) / Math.sin(d);
      var B = Math.sin(f * d) / Math.sin(d);
      var x = A * Math.cos(lat1) * Math.cos(lon1) + B * Math.cos(lat2) * Math.cos(lon2);
      var y = A * Math.cos(lat1) * Math.sin(lon1) + B * Math.cos(lat2) * Math.sin(lon2);
      var z = A * Math.sin(lat1) + B * Math.sin(lat2);
      pts.push([toDeg(Math.atan2(z, Math.sqrt(x * x + y * y))), toDeg(Math.atan2(y, x))]);
    }
    return pts;
  }

  function initMap(el, points) {
    if (!window.L || !points || !points.length) return;

    var ll = points.map(function (p) {
      return [p.lat, p.lon];
    });
    var line = [];
    var totalNm = 0;
    for (var i = 0; i < ll.length - 1; i++) {
      totalNm += gcNm(ll[i], ll[i + 1]);
      var seg = gcSegment(ll[i], ll[i + 1]);
      if (i > 0) seg = seg.slice(1);
      line = line.concat(seg);
    }

    var satellite = L.tileLayer(
      "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}",
      { attribution: "Tiles &copy; Esri", maxZoom: 18 }
    );
    var topo = L.tileLayer("https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png", {
      attribution:
        '&copy; <a href="https://opentopomap.org">OpenTopoMap</a> (CC-BY-SA)',
      maxZoom: 17,
    });
    var streets = L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OSM</a>',
      maxZoom: 19,
    });

    var map = L.map(el, {
      layers: [satellite],
      scrollWheelZoom: false,
      tap: true,
    });

    L.control.layers(
      { Satellite: satellite, Topo: topo, Streets: streets },
      null,
      { position: "topright", collapsed: true }
    ).addTo(map);

    L.polyline(line, {
      color: "#ff2a2a",
      weight: 3,
      opacity: 0.95,
    }).addTo(map);

    points.forEach(function (p, idx) {
      var ident = p.id || String(idx + 1);
      var icon = L.divIcon({
        className: "route-map-marker",
        html:
          '<span class="route-map-dot"></span>' +
          '<span class="route-map-ident">' +
          ident +
          "</span>",
        iconSize: [0, 0],
        iconAnchor: [6, 6],
      });
      var nm =
        idx < ll.length - 1
          ? Math.round(gcNm(ll[idx], ll[idx + 1])) + " nm to next"
          : "Finish";
      var title = p.name ? ident + " · " + p.name : ident;
      L.marker([p.lat, p.lon], { icon: icon })
        .bindPopup("<strong>" + title + "</strong><br>" + nm)
        .addTo(map);
    });

    map.fitBounds(L.latLngBounds(ll), { padding: [28, 28] });

    var hint = L.control({ position: "bottomleft" });
    hint.onAdd = function () {
      var div = L.DomUtil.create("div", "route-map-hint");
      div.textContent =
        Math.round(totalNm).toLocaleString() + " nm · click map to zoom";
      return div;
    };
    hint.addTo(map);

    map.once("click", function () {
      map.scrollWheelZoom.enable();
      var node = el.querySelector(".route-map-hint");
      if (node) node.textContent = Math.round(totalNm).toLocaleString() + " nm";
    });
  }

  function boot() {
    var maps = document.querySelectorAll(".route-map");
    maps.forEach(function (el) {
      if (el.dataset.ready) return;
      var dataEl = document.getElementById(el.id + "-data");
      if (!dataEl) return;
      try {
        initMap(el, JSON.parse(dataEl.value));
        el.dataset.ready = "1";
      } catch (err) {
        console.error("route map failed", err);
      }
    });
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", boot);
  } else {
    boot();
  }
})();
