(function () {
    function enhanceLogin() {
        if (document.body.id !== 'page-login-index') return;
        var form = document.querySelector('.loginform form.login-form');
        var providers = document.querySelector('.loginform .login-identityproviders');
        var google = providers && Array.from(providers.querySelectorAll('a')).find(function (link) {
            return /google/i.test(link.textContent) && /\/auth\/oauth2\/login\.php/.test(link.href);
        });
        // Keep the standard login visible if Google isn't available or the markup changes.
        if (!form || !google || form.closest('.cf-manual-login')) return;
        var details = document.createElement('details');
        details.className = 'cf-manual-login';
        var summary = document.createElement('summary');
        summary.textContent = 'Acceso con usuario y contraseña';
        details.appendChild(summary);
        form.parentNode.insertBefore(providers, form);
        form.parentNode.insertBefore(details, form);
        details.appendChild(form);
        if (new URLSearchParams(location.search).get('local') === '1' || document.getElementById('loginerrormessage')) {
            details.open = true;
        }
        // Keep the provider's original OAuth URL, icon and session parameters.
        Array.from(google.childNodes).forEach(function (node) {
            if (node.nodeType === 3) node.textContent = '';
        });
        var label = document.createElement('span');
        label.textContent = 'Entrar con Google';
        google.appendChild(label);
        google.setAttribute('aria-label', 'Entrar con Google');
        document.body.classList.add('cf-google-first');
    }
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', enhanceLogin);
    else enhanceLogin();
})();
