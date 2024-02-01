// this script renders all headers as clickable links
// see https://gohugo.io/content-management/cross-references/#use-of-ref-and-relref
window.onload = function() {
    var allHeadings = document.getElementsByTagName("h2");

    for (var i = 0; i < allHeadings.length; i++) {
        var heading = allHeadings[i].innerHTML;
        var id = allHeadings[i].id;
        allHeadings[i].innerHTML = `${heading}<a href=#${id} style='border-bottom: none;'><i data-feather="link"></i></a>`;
        feather.replace();
    }
};

