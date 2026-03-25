/**
 * 简洁全页离场：前往上传台 / Roche Log 时淡入暗角与微粒层（无旋转），再跳转。
 */
(function cruisePageExitInit() {
    if (window.__cruisePageExitBound) return;
    window.__cruisePageExitBound = true;

    const EXIT_MS = 500;

    function prefersReducedMotion() {
        return window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    }

    function injectOnce() {
        if (document.getElementById('cruisePageExit')) return;

        const css = `
.cruise-page-exit{position:fixed;inset:0;z-index:2500;pointer-events:none;opacity:0;visibility:hidden;transition:opacity .38s ease,visibility 0s linear .4s}
.cruise-page-exit.is-active{pointer-events:auto;opacity:1;visibility:visible;transition:opacity .34s ease,visibility 0s}
.cruise-page-exit__vignette{position:absolute;inset:0;background:radial-gradient(ellipse 80% 70% at 50% 42%,rgba(4,8,20,.12) 0%,rgba(2,5,14,.78) 65%,rgba(0,0,0,.93) 100%);pointer-events:none}
.cruise-page-exit .cruise-pe-dust{position:absolute;inset:0;opacity:1}
.cruise-pe-dust__vortex{position:absolute;inset:0;background:radial-gradient(ellipse 100% 55% at 50% -20%,rgba(150,200,255,.14) 0%,transparent 58%),radial-gradient(ellipse 70% 50% at 80% 100%,rgba(100,150,220,.08) 0%,transparent 50%);mix-blend-mode:screen;opacity:.85;pointer-events:none}
.cruise-pe-dust__drift{position:absolute;inset:0;background-image:radial-gradient(1px 1px at 12% 18%,rgba(255,255,255,.4) 50%,transparent 52%),radial-gradient(1px 1px at 73% 42%,rgba(200,230,255,.38) 50%,transparent 52%),radial-gradient(1.2px 1.2px at 38% 76%,rgba(255,255,255,.32) 50%,transparent 52%),radial-gradient(1px 1px at 88% 63%,rgba(180,215,255,.35) 50%,transparent 52%);background-size:100% 100%;opacity:.42;mix-blend-mode:screen;pointer-events:none}
.cruise-pe-dust__emulsion{position:absolute;inset:0;background:repeating-linear-gradient(0deg,rgba(0,0,0,0) 0,rgba(0,0,0,0) 4px,rgba(120,175,255,.022) 4px,rgba(120,175,255,.022) 5px);opacity:.38;mix-blend-mode:soft-light;pointer-events:none}
.cruise-pe-dust__sprocket{position:absolute;top:0;bottom:0;width:10px;background:repeating-linear-gradient(180deg,rgba(0,0,0,.4) 0,rgba(0,0,0,.4) 10px,transparent 10px,transparent 22px);opacity:.22;filter:blur(.3px)}
.cruise-pe-dust__sprocket--left{left:0;border-right:1px solid rgba(255,255,255,.06)}
.cruise-pe-dust__sprocket--right{right:0;border-left:1px solid rgba(255,255,255,.06)}
body.cruise-page-exit--body .container,body.cruise-page-exit--body>.sky-backdrop,body.cruise-page-exit--body>.stars{filter:blur(8px) brightness(.84) saturate(.9);transition:filter .34s ease}
@media (prefers-reduced-motion:reduce){
body.cruise-page-exit--body .container,body.cruise-page-exit--body>.sky-backdrop,body.cruise-page-exit--body>.stars{filter:none;transition:none}
}`;
        const style = document.createElement('style');
        style.textContent = css;
        document.head.appendChild(style);

        const el = document.createElement('div');
        el.className = 'cruise-page-exit';
        el.id = 'cruisePageExit';
        el.setAttribute('aria-hidden', 'true');
        el.innerHTML =
            '<div class="cruise-page-exit__vignette"></div>' +
            '<div class="cruise-pe-dust">' +
            '<div class="cruise-pe-dust__vortex"></div>' +
            '<div class="cruise-pe-dust__drift"></div>' +
            '<div class="cruise-pe-dust__emulsion"></div>' +
            '<div class="cruise-pe-dust__sprocket cruise-pe-dust__sprocket--left"></div>' +
            '<div class="cruise-pe-dust__sprocket cruise-pe-dust__sprocket--right"></div>' +
            '</div>';
        document.body.appendChild(el);
    }

    function isCruiseDestination(resolvedUrl) {
        try {
            const u = new URL(resolvedUrl);
            const cur = new URL(window.location.href);
            if (u.protocol !== cur.protocol || u.host !== cur.host) return false;
            const path = u.pathname.toLowerCase();
            return path.endsWith('/upload.html')
                || path.endsWith('/roche-log.html')
                || /(^|\/)upload\.html$/i.test(path)
                || /(^|\/)roche-log\.html$/i.test(path);
        } catch (_e) {
            return false;
        }
    }

    function navigateWithCruiseExit(absUrl) {
        if (prefersReducedMotion()) {
            window.location.href = absUrl;
            return;
        }
        injectOnce();
        const overlay = document.getElementById('cruisePageExit');
        if (!overlay) {
            window.location.href = absUrl;
            return;
        }
        if (overlay.classList.contains('is-active')) return;
        document.body.classList.add('cruise-page-exit--body');
        overlay.classList.add('is-active');
        window.setTimeout(() => {
            window.location.href = absUrl;
        }, EXIT_MS);
    }

    document.addEventListener(
        'click',
        function (e) {
            if (e.defaultPrevented) return;
            if (e.button !== 0) return;
            if (e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
            const t = e.target;
            if (!t || !t.closest) return;
            const a = t.closest('a');
            if (!a) return;
            const targetAttr = a.getAttribute('target');
            if (targetAttr && targetAttr !== '_self') return;
            const hrefAttr = a.getAttribute('href');
            if (!hrefAttr || hrefAttr.trim() === '' || hrefAttr.startsWith('#')) return;
            let resolved;
            try {
                resolved = new URL(a.href, window.location.href).href;
            } catch (_e) {
                return;
            }
            if (!isCruiseDestination(resolved)) return;
            e.preventDefault();
            navigateWithCruiseExit(resolved);
        },
        true
    );

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', injectOnce);
    } else {
        injectOnce();
    }
})();
