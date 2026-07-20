/**
 * Selfhost AI Welcome Page
 * Dynamic rendering of services and credentials from data.json
 */

(function() {
    'use strict';

    // ============================================
    // CINEMATIC ANIMATIONS MODULE
    // ============================================
    const CinematicAnimations = {
        CONFETTI_STORAGE_KEY: 'selfhost_ai_welcomed',

        isFirstVisit() {
            return !localStorage.getItem(this.CONFETTI_STORAGE_KEY);
        },

        markVisited() {
            localStorage.setItem(this.CONFETTI_STORAGE_KEY, Date.now().toString());
        },

        triggerConfetti() {
            if (!window.confetti) return;

            const colors = ['#3ECF8E', '#24B374', '#47DF97', '#ffffff', '#75E7B1'];
            const defaults = {
                spread: 60,
                ticks: 100,
                gravity: 1,
                decay: 0.94,
                startVelocity: 30,
                colors: colors
            };

            function fire(particleRatio, opts) {
                confetti({
                    ...defaults,
                    ...opts,
                    particleCount: Math.floor(200 * particleRatio)
                });
            }

            // Staggered confetti bursts
            fire(0.25, { spread: 26, startVelocity: 55 });
            fire(0.2, { spread: 60 });
            fire(0.35, { spread: 100, decay: 0.91, scalar: 0.8 });
            fire(0.1, { spread: 120, startVelocity: 25, decay: 0.92, scalar: 1.2 });
            fire(0.1, { spread: 120, startVelocity: 45 });

            // Side cannons
            setTimeout(() => {
                confetti({
                    particleCount: 50,
                    angle: 60,
                    spread: 55,
                    origin: { x: 0 },
                    colors: colors
                });
                confetti({
                    particleCount: 50,
                    angle: 120,
                    spread: 55,
                    origin: { x: 1 },
                    colors: colors
                });
            }, 250);
        },

        init() {
            // Check for first visit and trigger confetti
            if (this.isFirstVisit()) {
                setTimeout(() => {
                    this.triggerConfetti();
                    this.markVisited();
                }, 800);
            }
        }
    };

    // ============================================
    // ICONS - SVG icons as template functions
    // ============================================
    const Icons = {
        copy: (className = '') => `
            <svg class="${className}" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z"/>
            </svg>`,

        check: (className = '') => `
            <svg class="${className}" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"/>
            </svg>`,

        eyeOpen: (className = '') => `
            <svg class="${className}" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
            </svg>`,

        eyeClosed: (className = '') => `
            <svg class="${className}" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.88 9.88l-3.29-3.29m7.532 7.532l3.29 3.29M3 3l3.59 3.59m0 0A9.953 9.953 0 0112 5c4.478 0 8.268 2.943 9.543 7a10.025 10.025 0 01-4.132 5.411m0 0L21 21"/>
            </svg>`,

        externalLink: (className = '') => `
            <svg class="${className}" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 6H6a2 2 0 00-2 2v10a2 2 0 002 2h10a2 2 0 002-2v-4M14 4h6m0 0v6m0-6L10 14"/>
            </svg>`,

        server: (className = '') => `
            <svg class="${className}" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 11H5m14 0a2 2 0 012 2v6a2 2 0 01-2 2H5a2 2 0 01-2-2v-6a2 2 0 012-2m14 0V9a2 2 0 00-2-2M5 11V9a2 2 0 012-2m0 0V5a2 2 0 012-2h6a2 2 0 012 2v2M7 7h10"/>
            </svg>`,

        bolt: (className = '') => `
            <svg class="${className}" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
            </svg>`,

        refresh: (className = '') => `
            <svg class="${className}" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
            </svg>`,

        terminal: (className = '') => `
            <svg class="${className}" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 9l3 3-3 3m5 0h3M5 20h14a2 2 0 002-2V6a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z"/>
            </svg>`,

        book: (className = '') => `
            <svg class="${className}" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6.253v13m0-13C10.832 5.477 9.246 5 7.5 5S4.168 5.477 3 6.253v13C4.168 18.477 5.754 18 7.5 18s3.332.477 4.5 1.253m0-13C13.168 5.477 14.754 5 16.5 5c1.747 0 3.332.477 4.5 1.253v13C19.832 18.477 18.247 18 16.5 18c-1.746 0-3.332.477-4.5 1.253"/>
            </svg>`,

        warning: (className = '') => `
            <svg class="${className}" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/>
            </svg>`,

        changelog: (className = '') => `
            <svg class="${className}" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-3 7h3m-3 4h3m-6-4h.01M9 16h.01"/>
            </svg>`
    };

    // ============================================
    // DATA - Service metadata and commands
    // ============================================
    const SERVICE_METADATA = {
        'appsmith': {
            name: 'Appsmith',
            description: 'Low-code Internal Tools',
            icon: 'AS',
            color: 'bg-[#5f2dde]',
            category: 'tools',
            docsUrl: 'https://docs.appsmith.com'
        },
        'n8n': {
            name: 'n8n',
            description: 'Workflow Automation',
            icon: 'n8n',
            color: 'bg-[#EA4B71]',
            category: 'automation',
            docsUrl: 'https://docs.n8n.io'
        },
        'flowise': {
            name: 'Flowise',
            description: 'AI Agent Builder',
            icon: 'FL',
            color: 'bg-[#673AB7]',
            category: 'ai',
            docsUrl: 'https://docs.flowiseai.com'
        },
        'open-webui': {
            name: 'Open WebUI',
            description: 'ChatGPT-like Interface',
            icon: 'AI',
            color: 'bg-black',
            category: 'ai',
            docsUrl: 'https://docs.openwebui.com'
        },
        'grafana': {
            name: 'Grafana',
            description: 'Monitoring Dashboard',
            icon: 'GF',
            color: 'bg-[#F46800]',
            category: 'monitoring',
            docsUrl: 'https://grafana.com/docs'
        },
        'prometheus': {
            name: 'Prometheus',
            description: 'Metrics Collection',
            icon: 'PM',
            color: 'bg-[#E6522C]',
            category: 'monitoring',
            docsUrl: 'https://prometheus.io/docs'
        },
        'portainer': {
            name: 'Portainer',
            description: 'Docker Management UI',
            icon: 'PT',
            color: 'bg-[#13BEF9]',
            category: 'infra',
            docsUrl: 'https://docs.portainer.io'
        },
        'databasus': {
            name: 'Databasus',
            description: 'Database Backups & Monitoring',
            icon: 'DB',
            color: 'bg-[#155DFC]',
            category: 'database',
            docsUrl: 'https://databasus.com/'
        },
        'langfuse': {
            name: 'Langfuse',
            description: 'AI Observability',
            icon: 'LF',
            color: 'bg-[#0A60B5]',
            category: 'ai',
            docsUrl: 'https://langfuse.com/docs'
        },
        'supabase': {
            name: 'Supabase',
            description: 'Backend as a Service',
            icon: 'SB',
            color: 'bg-[#3ECF8E]',
            category: 'database',
            docsUrl: 'https://supabase.com/docs'
        },
        'dify': {
            name: 'Dify',
            description: 'AI Application Platform',
            icon: 'DF',
            color: 'bg-[#1C64F2]',
            category: 'ai',
            docsUrl: 'https://docs.dify.ai'
        },
        'qdrant': {
            name: 'Qdrant',
            description: 'Vector Database',
            icon: 'QD',
            color: 'bg-[#DC244C]',
            category: 'database',
            docsUrl: 'https://qdrant.tech/documentation'
        },
        'weaviate': {
            name: 'Weaviate',
            description: 'Vector Database',
            icon: 'WV',
            color: 'bg-[#38B349]',
            category: 'database',
            docsUrl: 'https://weaviate.io/developers/weaviate'
        },
        'neo4j': {
            name: 'Neo4j',
            description: 'Graph Database',
            icon: 'N4',
            color: 'bg-[#0A6190]',
            category: 'database',
            docsUrl: 'https://neo4j.com/docs'
        },
        'nocodb': {
            name: 'NocoDB',
            description: 'Spreadsheet Database',
            icon: 'NC',
            color: 'bg-[#3433C1]',
            category: 'database',
            docsUrl: 'https://nocodb.com/docs/product-docs'
        },
        'searxng': {
            name: 'SearXNG',
            description: 'Private Metasearch Engine',
            icon: 'SX',
            color: 'bg-[#3EBBE7]',
            category: 'tools',
            docsUrl: 'https://docs.searxng.org'
        },
        'ragapp': {
            name: 'RAGApp',
            description: 'RAG UI & API',
            icon: 'RA',
            color: 'bg-amber-500',
            category: 'ai',
            docsUrl: 'https://github.com/ragapp/ragapp'
        },
        'ragflow': {
            name: 'RAGFlow',
            description: 'Document Understanding RAG',
            icon: 'RF',
            color: 'bg-[#6C63FF]',
            category: 'ai',
            docsUrl: 'https://ragflow.io/docs'
        },
        'lightrag': {
            name: 'LightRAG',
            description: 'Graph-based RAG',
            icon: 'LR',
            color: 'bg-lime-500',
            category: 'ai',
            docsUrl: 'https://github.com/HKUDS/LightRAG'
        },
        'letta': {
            name: 'Letta',
            description: 'Agent Server & SDK',
            icon: 'LT',
            color: 'bg-violet-500',
            category: 'ai',
            docsUrl: 'https://docs.letta.com'
        },
        'comfyui': {
            name: 'ComfyUI',
            description: 'Stable Diffusion UI',
            icon: 'CU',
            color: 'bg-[#172DD7]',
            category: 'ai',
            docsUrl: 'https://docs.comfy.org'
        },
        'invokeai': {
            name: 'InvokeAI',
            description: 'Stable Diffusion Studio',
            icon: 'IA',
            color: 'bg-[#7C3AED]',
            category: 'ai',
            docsUrl: 'https://invoke.ai'
        },
        'libretranslate': {
            name: 'LibreTranslate',
            description: 'Translation API',
            icon: 'TR',
            color: 'bg-[#295F98]',
            category: 'tools',
            docsUrl: 'https://libretranslate.com/docs'
        },
        'docling': {
            name: 'Docling',
            description: 'Document Converter',
            icon: 'DL',
            color: 'bg-[#006699]',
            category: 'tools',
            docsUrl: 'https://docling-project.github.io/docling'
        },
        'paddleocr': {
            name: 'PaddleOCR',
            description: 'OCR API Server',
            icon: 'OC',
            color: 'bg-[#2932E1]',
            category: 'tools',
            docsUrl: 'https://www.paddleocr.ai/latest/en/index.html'
        },
        'postiz': {
            name: 'Postiz',
            description: 'Social Publishing Platform',
            icon: 'PZ',
            color: 'bg-violet-500',
            category: 'tools',
            docsUrl: 'https://docs.postiz.com'
        },
        'temporal-ui': {
            name: 'Temporal UI',
            description: 'Postiz Workflow Orchestration',
            icon: 'TM',
            color: 'bg-violet-500',
            category: 'tools',
            docsUrl: 'https://docs.temporal.io/'
        },
        'waha': {
            name: 'WAHA',
            description: 'WhatsApp HTTP API',
            icon: 'WA',
            color: 'bg-[#25D366]',
            category: 'tools',
            docsUrl: 'https://waha.devlike.pro/docs'
        },
        'crawl4ai': {
            name: 'Crawl4AI',
            description: 'Web Crawler for AI',
            icon: 'C4',
            color: 'bg-[#50FFFF]',
            category: 'tools',
            docsUrl: 'https://docs.crawl4ai.com'
        },
        'gost': {
            name: 'Gost Proxy',
            description: 'Proxy for Outbound Traffic',
            icon: 'GP',
            color: 'bg-[#4051B5]',
            category: 'infra',
            docsUrl: 'https://gost.run/en/'
        },
        'gotenberg': {
            name: 'Gotenberg',
            description: 'PDF Generator API',
            icon: 'GT',
            color: 'bg-red-500',
            category: 'tools',
            docsUrl: 'https://gotenberg.dev/docs/getting-started/introduction'
        },
        'ollama': {
            name: 'Ollama',
            description: 'Local LLM Runner',
            icon: 'OL',
            color: 'bg-black',
            category: 'ai',
            docsUrl: 'https://docs.ollama.com/'
        },
        'redis': {
            name: 'Redis (Valkey)',
            description: 'In-Memory Data Store',
            icon: 'RD',
            color: 'bg-[#D82C20]',
            category: 'infra',
            docsUrl: 'https://valkey.io/docs'
        },
        'postgres': {
            name: 'PostgreSQL',
            description: 'Relational Database',
            icon: 'PG',
            color: 'bg-[#336791]',
            category: 'infra',
            docsUrl: 'https://www.postgresql.org/docs'
        },
        'python-runner': {
            name: 'Python Runner',
            description: 'Custom Python Scripts',
            icon: 'PY',
            color: 'bg-[#3776AB]',
            category: 'tools',
            docsUrl: 'https://docs.python.org'
        },
        'uptime-kuma': {
            name: 'Uptime Kuma',
            description: 'Uptime Monitoring Dashboard',
            icon: 'UK',
            color: 'bg-[#5CDD8B]',
            category: 'monitoring',
            docsUrl: 'https://github.com/louislam/uptime-kuma'
        },
        'cloudflare-tunnel': {
            name: 'Cloudflare Tunnel',
            description: 'Zero-Trust Network Access',
            icon: 'CF',
            color: 'bg-[#F48120]',
            category: 'infra',
            docsUrl: 'https://developers.cloudflare.com/cloudflare-one/connections/connect-apps'
        }
    };

    const COMMANDS = [
        { cmd: 'make status', desc: 'Show container status' },
        { cmd: 'make logs', desc: 'View logs (all services)' },
        { cmd: 'make logs s=<service>', desc: 'View logs for specific service' },
        { cmd: 'make monitor', desc: 'Live CPU/memory monitoring' },
        { cmd: 'make restart', desc: 'Restart all services' },
        { cmd: 'make stop', desc: 'Stop all services' },
        { cmd: 'make start', desc: 'Start all services' },
        { cmd: 'make show-restarts', desc: 'Show restart count per container' },
        { cmd: 'make doctor', desc: 'Run system diagnostics' },
        { cmd: 'make update', desc: 'Update system and services' },
        { cmd: 'make git-pull', desc: 'Update for forks (merge from upstream)' },
        { cmd: 'make import', desc: 'Import n8n workflows (use n=10 to limit)' },
        { cmd: 'make clean', desc: 'Remove unused Docker resources' }
    ];

    // ============================================
    // UTILS - Helper functions
    // ============================================

    /**
     * Escape HTML to prevent XSS
     */
    function escapeHtml(text) {
        if (!text) return '';
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }

    /**
     * Copy text to clipboard and show visual feedback
     */
    async function copyToClipboard(text, button) {
        try {
            await navigator.clipboard.writeText(text);
            showCopySuccess(button);
            return true;
        } catch (err) {
            console.error('Failed to copy:', err);
            return false;
        }
    }

    /**
     * Show copy success visual feedback
     */
    function showCopySuccess(button) {
        const copyIcon = button.querySelector('.icon-copy');
        const checkIcon = button.querySelector('.icon-check');

        if (copyIcon && checkIcon) {
            copyIcon.classList.add('hidden');
            checkIcon.classList.remove('hidden');

            setTimeout(() => {
                copyIcon.classList.remove('hidden');
                checkIcon.classList.add('hidden');
            }, 2000);
        }
    }

    /**
     * Toggle password visibility
     */
    function togglePasswordVisibility(button, passwordSpan, password) {
        const isHidden = passwordSpan.dataset.hidden === 'true';
        const eyeOpen = button.querySelector('.icon-eye-open');
        const eyeClosed = button.querySelector('.icon-eye-closed');

        if (isHidden) {
            passwordSpan.textContent = password;
            passwordSpan.dataset.hidden = 'false';
            button.setAttribute('aria-pressed', 'true');
            eyeOpen?.classList.add('hidden');
            eyeClosed?.classList.remove('hidden');
        } else {
            passwordSpan.textContent = '*'.repeat(Math.min(password.length, 12));
            passwordSpan.dataset.hidden = 'true';
            button.setAttribute('aria-pressed', 'false');
            eyeOpen?.classList.remove('hidden');
            eyeClosed?.classList.add('hidden');
        }
    }

    // ============================================
    // COMPONENTS - UI component functions
    // ============================================

    /**
     * Create a copy button for any text
     */
    function createCopyButton(textToCopy) {
        const button = document.createElement('button');
        button.type = 'button';
        button.className = 'p-1.5 rounded-lg hover:bg-surface-400 transition-colors focus:outline-none focus:ring-2 focus:ring-brand/50';
        button.setAttribute('aria-label', 'Copy to clipboard');
        button.innerHTML = `
            ${Icons.copy('w-4 h-4 text-gray-500 hover:text-brand transition-colors icon-copy')}
            ${Icons.check('w-4 h-4 text-brand icon-check hidden')}
        `;

        button.addEventListener('click', () => copyToClipboard(textToCopy, button));
        return button;
    }

    /**
     * Create password field with toggle and copy buttons
     */
    function createPasswordField(password) {
        const container = document.createElement('div');
        container.className = 'flex items-center gap-1 min-w-0';

        // Password display
        const passwordSpan = document.createElement('span');
        passwordSpan.className = 'font-mono text-sm select-all text-gray-300 break-all';
        passwordSpan.textContent = '*'.repeat(Math.min(password.length, 12));
        passwordSpan.dataset.password = password;
        passwordSpan.dataset.hidden = 'true';

        // Toggle visibility button
        const toggleBtn = document.createElement('button');
        toggleBtn.type = 'button';
        toggleBtn.className = 'p-1.5 rounded-lg hover:bg-surface-400 transition-colors focus:outline-none focus:ring-2 focus:ring-brand/50';
        toggleBtn.setAttribute('aria-label', 'Toggle password visibility');
        toggleBtn.setAttribute('aria-pressed', 'false');
        toggleBtn.innerHTML = `
            ${Icons.eyeOpen('w-4 h-4 text-gray-500 hover:text-brand transition-colors icon-eye-open')}
            ${Icons.eyeClosed('w-4 h-4 text-gray-500 hover:text-brand transition-colors icon-eye-closed hidden')}
        `;

        toggleBtn.addEventListener('click', () => {
            togglePasswordVisibility(toggleBtn, passwordSpan, password);
        });

        // Copy button (reusing the component)
        const copyBtn = createCopyButton(password);

        container.appendChild(toggleBtn);
        container.appendChild(passwordSpan);
        container.appendChild(copyBtn);

        return container;
    }

    /**
     * Create a credential row with label and value
     */
    function createCredentialRow(label, value, isSecret) {
        const row = document.createElement('div');
        row.className = 'flex justify-between items-center gap-2 min-w-0';

        const labelSpan = document.createElement('span');
        labelSpan.className = 'text-gray-500 text-sm flex-shrink-0';
        labelSpan.textContent = `${label}:`;
        row.appendChild(labelSpan);

        if (isSecret) {
            row.appendChild(createPasswordField(value));
        } else {
            const valueContainer = document.createElement('div');
            valueContainer.className = 'flex items-center gap-1 min-w-0';

            const valueSpan = document.createElement('span');
            valueSpan.className = 'font-mono text-sm select-all text-gray-300 break-all';
            valueSpan.textContent = value;

            valueContainer.appendChild(valueSpan);
            valueContainer.appendChild(createCopyButton(value));
            row.appendChild(valueContainer);
        }

        return row;
    }

    /**
     * Mapping of extra fields to display labels
     * Fields not in this map are skipped (internal_api, internal_url shown in header)
     */
    const EXTRA_FIELD_LABELS = {
        workers: { label: 'Workers', isSecret: false },
        mounted_dir: { label: 'Mount', isSecret: false },
        entry_file: { label: 'Entry', isSecret: false },
        logs_command: { label: 'Logs', isSecret: false },
        dashboard: { label: 'Dashboard', isLink: true },
        docs: { label: 'Docs', isLink: true },
        api_endpoint: { label: 'API', isLink: true },
        admin: { label: 'Admin', isLink: true },
        ui: { label: 'UI', isLink: true },
        service_role_key: { label: 'Service Key', isSecret: true },
        bolt_port: { label: 'Bolt Port', isSecret: false },
        pg_host: { label: 'PG Host', isSecret: false },
        pg_port: { label: 'PG Port', isSecret: false },
        pg_user: { label: 'PG User', isSecret: false },
        pg_password: { label: 'PG Password', isSecret: true },
        pg_db: { label: 'PG Database', isSecret: false },
        swagger_user: { label: 'Swagger User', isSecret: false },
        swagger_pass: { label: 'Swagger Pass', isSecret: true },
        internal_host: { label: 'Internal Host', isSecret: false },
        internal_port: { label: 'Internal Port', isSecret: false },
        database: { label: 'Database', isSecret: false },
        proxy_url: { label: 'Proxy URL', isSecret: true },
        upstream_proxy: { label: 'Upstream', isSecret: true }
    };

    /**
     * Create a link row with label and "Link" text + icon
     * @param {string} label - Base label (e.g., "Dashboard", "Docs")
     * @param {string} url - The URL to link to
     * @param {string} serviceName - Optional service name to prefix label (e.g., "Qdrant")
     */
    function createLinkRow(label, url, serviceName) {
        const row = document.createElement('div');
        row.className = 'flex justify-between items-center';

        // Create service-specific label like "Qdrant Dashboard" instead of just "Dashboard"
        const fullLabel = serviceName ? `${serviceName} ${label}` : label;

        const labelSpan = document.createElement('span');
        labelSpan.className = 'text-gray-500 text-sm';
        labelSpan.textContent = `${fullLabel}:`;
        row.appendChild(labelSpan);

        // Container to align with other rows that have copy buttons
        const valueContainer = document.createElement('div');
        valueContainer.className = 'flex items-center gap-1 pr-2';

        const link = document.createElement('a');
        link.href = url;
        link.target = '_blank';
        link.rel = 'noopener';
        link.className = 'text-brand hover:text-brand-400 text-sm font-medium inline-flex items-center gap-1 group transition-colors';
        link.innerHTML = `
            Link
            ${Icons.externalLink('w-3 h-3 group-hover:translate-x-0.5 transition-transform')}
        `;
        valueContainer.appendChild(link);
        row.appendChild(valueContainer);

        return row;
    }

    /**
     * Create bottom section with credentials and extra info
     * @param {Object} creds - Credentials object
     * @param {Object} extra - Extra data object
     * @param {string} serviceName - Service name for link labels
     */
    function createBottomSection(creds, extra, serviceName) {
        const section = document.createElement('div');
        section.className = 'mt-4 pt-4 border-t border-surface-400 space-y-1';

        // Handle credentials note (special case - just show note text)
        if (creds && creds.note) {
            const noteP = document.createElement('p');
            noteP.className = 'text-sm text-gray-500 italic whitespace-pre-line';
            noteP.textContent = creds.note;
            section.appendChild(noteP);
        }

        // Add credential fields
        if (creds) {
            if (creds.username) {
                section.appendChild(createCredentialRow('Username', creds.username, false));
            }
            if (creds.password) {
                section.appendChild(createCredentialRow('Password', creds.password, true));
            }
            if (creds.api_key) {
                section.appendChild(createCredentialRow('API Key', creds.api_key, true));
            }
            if (creds.api_token) {
                section.appendChild(createCredentialRow('API Token', creds.api_token, true));
            }
            if (creds.user_token) {
                section.appendChild(createCredentialRow('User Token', creds.user_token, true));
            }
        }

        // Add extra fields (skip internal_api/internal_url - shown in header)
        if (extra) {
            for (const [key, value] of Object.entries(extra)) {
                // Skip fields shown in header
                if (key === 'internal_api' || key === 'internal_url') continue;

                // Handle recommendation as plain italic text (like credentials.note)
                if (key === 'recommendation' && value) {
                    const noteP = document.createElement('p');
                    noteP.className = 'text-sm text-gray-500 italic';
                    noteP.textContent = value;
                    section.appendChild(noteP);
                    continue;
                }

                const fieldConfig = EXTRA_FIELD_LABELS[key];
                if (fieldConfig && value) {
                    if (fieldConfig.isLink) {
                        section.appendChild(createLinkRow(fieldConfig.label, value, serviceName));
                    } else {
                        section.appendChild(createCredentialRow(fieldConfig.label, value, fieldConfig.isSecret));
                    }
                }
            }
        }

        return section;
    }

    /**
     * Create service card header
     */
    function createCardHeader(metadata, serviceData) {
        const header = document.createElement('div');
        header.className = 'flex items-start gap-4';

        // Icon
        const iconDiv = document.createElement('div');
        iconDiv.className = `${metadata.color} w-11 h-11 rounded-lg flex items-center justify-center text-white font-bold text-sm flex-shrink-0 shadow-lg`;
        iconDiv.textContent = metadata.icon;

        // Content
        const content = document.createElement('div');
        content.className = 'flex-1 min-w-0';

        const title = document.createElement('h3');
        title.className = 'font-semibold text-white';

        if (metadata.docsUrl) {
            const titleLink = document.createElement('a');
            titleLink.href = metadata.docsUrl;
            titleLink.target = '_blank';
            titleLink.rel = 'noopener';
            titleLink.className = 'hover:text-brand transition-colors';
            titleLink.textContent = metadata.name;
            title.appendChild(titleLink);
        } else {
            title.textContent = metadata.name;
        }

        const desc = document.createElement('p');
        desc.className = 'text-sm text-gray-500 mb-2';
        desc.textContent = metadata.description;

        content.appendChild(title);
        content.appendChild(desc);

        // Check if service has internal URL in extra
        const hasInternalUrl = serviceData.extra && (serviceData.extra.internal_api || serviceData.extra.internal_url);

        // External link (if hostname exists)
        if (serviceData.hostname) {
            const link = document.createElement('a');
            link.href = `https://${serviceData.hostname}`;
            link.target = '_blank';
            link.rel = 'noopener';
            link.className = 'text-brand hover:text-brand-400 text-sm font-medium inline-flex items-center gap-1 group transition-colors';
            link.innerHTML = `
                ${escapeHtml(serviceData.hostname)}
                ${Icons.externalLink('w-3 h-3 group-hover:translate-x-0.5 transition-transform')}
            `;
            content.appendChild(link);
        }

        // Internal URL (shown from extra section, no duplicate "Internal service" text)
        if (hasInternalUrl) {
            const internalDiv = document.createElement('div');
            internalDiv.className = serviceData.hostname ? 'mt-1' : '';
            const internalUrl = serviceData.extra.internal_api || serviceData.extra.internal_url;
            internalDiv.innerHTML = `<span class="text-xs text-gray-600 font-mono break-all">Internal: ${escapeHtml(internalUrl)}</span>`;
            content.appendChild(internalDiv);
        }

        // Only show "Internal service" if no hostname AND no internal URL
        if (!serviceData.hostname && !hasInternalUrl) {
            const internalSpan = document.createElement('span');
            internalSpan.className = 'text-sm text-gray-600 italic';
            internalSpan.textContent = 'Internal service';
            content.appendChild(internalSpan);
        }

        // Make icon clickable if docsUrl is available
        if (metadata.docsUrl) {
            const iconLink = document.createElement('a');
            iconLink.href = metadata.docsUrl;
            iconLink.target = '_blank';
            iconLink.rel = 'noopener';
            iconLink.title = `Open ${metadata.name} documentation`;
            iconLink.className = 'flex-shrink-0 hover:scale-110 transition-transform';
            iconLink.appendChild(iconDiv);
            header.appendChild(iconLink);
        } else {
            header.appendChild(iconDiv);
        }
        header.appendChild(content);

        return header;
    }

    /**
     * Render a single service card
     */
    function renderServiceCard(key, serviceData) {
        const metadata = SERVICE_METADATA[key] || {
            name: key,
            description: '',
            icon: key.substring(0, 2).toUpperCase(),
            color: 'bg-gray-600'
        };

        const card = document.createElement('article');
        card.className = 'bg-surface-100 rounded-xl border border-surface-400 p-5 hover:border-brand/30 hover:bg-surface-200 transition-all min-w-0 overflow-hidden';

        // Build card using DOM API (no innerHTML + setTimeout hack)
        const header = createCardHeader(metadata, serviceData);
        card.appendChild(header);

        // Bottom section with credentials and extra info
        const hasCredentials = serviceData.credentials && Object.keys(serviceData.credentials).length > 0;
        const hasExtra = serviceData.extra && Object.keys(serviceData.extra).some(
            key => key !== 'internal_api' && key !== 'internal_url' && EXTRA_FIELD_LABELS[key]
        );

        if (hasCredentials || hasExtra) {
            const bottomSection = createBottomSection(serviceData.credentials, serviceData.extra, metadata.name);
            card.appendChild(bottomSection);
        }

        return card;
    }

    // ============================================
    // APP - Initialization and rendering
    // ============================================

    // DOM Elements
    const servicesContainer = document.getElementById('services-container');
    const quickstartContainer = document.getElementById('quickstart-container');
    const commandsContainer = document.getElementById('commands-container');
    const changelogContainer = document.getElementById('changelog-container');
    const domainInfo = document.getElementById('domain-info');

    /**
     * Inject section icons from JS (replaces inline SVG in HTML)
     */
    function injectSectionIcons() {
        document.querySelectorAll('[data-section-icon]').forEach(container => {
            const iconName = container.dataset.sectionIcon;
            if (Icons[iconName]) {
                container.innerHTML = Icons[iconName]('w-5 h-5 text-brand');
            }
        });
    }

    /**
     * Render all services
     */
    function renderServices(services) {
        if (!servicesContainer) return;
        servicesContainer.innerHTML = '';

        if (!services || Object.keys(services).length === 0) {
            servicesContainer.innerHTML = `
                <div class="col-span-full text-center py-12 text-gray-500">
                    <p>No services configured. Run the installer to set up services.</p>
                </div>
            `;
            return;
        }

        // Sort all services alphabetically by display name
        const sortedKeys = Object.keys(services).sort((a, b) => {
            const aName = (SERVICE_METADATA[a]?.name || a).toLowerCase();
            const bName = (SERVICE_METADATA[b]?.name || b).toLowerCase();
            return aName.localeCompare(bName);
        });

        // Use DocumentFragment for better performance
        const fragment = document.createDocumentFragment();
        sortedKeys.forEach(key => {
            fragment.appendChild(renderServiceCard(key, services[key]));
        });
        servicesContainer.appendChild(fragment);
    }

    /**
     * Render quick start steps
     */
    function renderQuickStart(steps) {
        if (!quickstartContainer) return;
        quickstartContainer.innerHTML = '';

        if (!steps || steps.length === 0) {
            // Default steps if none provided
            steps = [
                { step: 1, title: 'Log into n8n', description: 'Use the email you provided during installation' },
                { step: 2, title: 'Create your first workflow', description: 'Start with a Manual Trigger + HTTP Request nodes' },
                { step: 3, title: 'Monitor your system', description: 'Use Grafana to track performance' }
            ];
        }

        const fragment = document.createDocumentFragment();
        steps.forEach(item => {
            const stepEl = document.createElement('div');
            stepEl.className = 'flex items-start gap-4 p-4 bg-surface-100 rounded-xl border border-surface-400 hover:border-brand/30 hover:bg-surface-200 transition-all';

            stepEl.innerHTML = `
                <div class="w-8 h-8 rounded-full bg-brand/20 border border-brand/30 text-brand flex items-center justify-center font-semibold text-sm flex-shrink-0">
                    ${item.step}
                </div>
                <div>
                    <h4 class="font-semibold text-white">${escapeHtml(item.title)}</h4>
                    <p class="text-sm text-gray-500">${escapeHtml(item.description)}</p>
                </div>
            `;

            fragment.appendChild(stepEl);
        });
        quickstartContainer.appendChild(fragment);
    }

    /**
     * Render make commands
     */
    function renderCommands() {
        if (!commandsContainer) return;
        commandsContainer.innerHTML = '';

        const grid = document.createElement('div');
        grid.className = 'grid gap-4 sm:grid-cols-2 lg:grid-cols-3';

        COMMANDS.forEach(item => {
            const cmdEl = document.createElement('div');
            cmdEl.className = 'flex items-start gap-3 p-3 rounded-lg bg-surface-200/50 border border-surface-400 hover:border-brand/30 hover:bg-surface-300 transition-all';

            // Command content
            const content = document.createElement('div');
            content.className = 'flex flex-col gap-1 flex-1 min-w-0';
            content.innerHTML = `
                <code class="text-brand font-mono text-sm">${escapeHtml(item.cmd)}</code>
                <span class="text-gray-500 text-xs">${escapeHtml(item.desc)}</span>
            `;

            // Copy button
            const copyBtn = createCopyButton(item.cmd);
            copyBtn.className = 'p-1.5 rounded-lg hover:bg-surface-400 transition-colors focus:outline-none focus:ring-2 focus:ring-brand/50 flex-shrink-0';

            cmdEl.appendChild(content);
            cmdEl.appendChild(copyBtn);
            grid.appendChild(cmdEl);
        });

        commandsContainer.appendChild(grid);
    }

    /**
     * Render changelog content
     */
    function renderChangelog(content) {
        if (!changelogContainer) return;
        changelogContainer.innerHTML = '';

        if (!content) {
            changelogContainer.innerHTML = `
                <p class="text-gray-500 text-center py-8">Changelog not available</p>
            `;
            return;
        }

        const pre = document.createElement('pre');
        pre.className = 'text-sm text-gray-300 font-mono whitespace-pre-wrap break-words leading-relaxed';
        pre.textContent = content;
        changelogContainer.appendChild(pre);
    }

    /**
     * Render error state in services container
     */
    function renderServicesError() {
        if (!servicesContainer) return;

        servicesContainer.innerHTML = `
            <div class="col-span-full bg-red-900/20 border border-red-800/50 rounded-xl p-6 text-center" role="alert">
                ${Icons.warning('w-12 h-12 mx-auto text-red-500 mb-4')}
                <h3 class="font-semibold text-red-400 mb-2">Unable to load service data</h3>
                <p class="text-sm text-red-300/80">Make sure the installation completed successfully and data.json was generated.</p>
            </div>
        `;
    }

    /**
     * Load data and render page
     */
    async function init() {
        // Inject section icons
        injectSectionIcons();

        // Always render commands (static content)
        renderCommands();

        // Fetch both JSON files in parallel for better performance
        // Each fetch is handled independently - changelog failure won't affect main data
        const [changelogResult, dataResult] = await Promise.allSettled([
            fetch('changelog.json').then(r => r.ok ? r.json() : null),
            fetch('data.json').then(r => r.ok ? r.json() : Promise.reject(new Error(`HTTP ${r.status}`)))
        ]);

        // Handle changelog (independent - failures don't break the page)
        if (changelogResult.status === 'fulfilled' && changelogResult.value?.content) {
            renderChangelog(changelogResult.value.content);
        } else {
            if (changelogResult.status === 'rejected') {
                console.error('Error loading changelog:', changelogResult.reason);
            }
            renderChangelog(null);
        }

        // Handle main data
        if (dataResult.status === 'fulfilled' && dataResult.value) {
            const data = dataResult.value;

            // Update domain info
            if (domainInfo) {
                if (data.domain) {
                    domainInfo.textContent = `Domain: ${data.domain}`;
                }
                if (data.generated_at) {
                    const date = new Date(data.generated_at);
                    domainInfo.textContent += ` | Generated: ${date.toLocaleString()}`;
                }
            }

            // Render services
            renderServices(data.services);

            // Render quick start
            renderQuickStart(data.quick_start);
        } else {
            console.error('Error loading data:', dataResult.reason);

            // Show error in UI
            renderServicesError();

            // Still render default quick start
            renderQuickStart(null);
        }

        // Initialize confetti animation on first visit
        CinematicAnimations.init();
    }

    // Initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
