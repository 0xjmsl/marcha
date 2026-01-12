/**
 * Marcha Documentation - Interactive Features
 * Vanilla JavaScript - No dependencies
 */

(function() {
  'use strict';

  // ============================================
  // Theme Management
  // ============================================

  const THEME_KEY = 'marcha-docs-theme';

  function getPreferredTheme() {
    const stored = localStorage.getItem(THEME_KEY);
    if (stored) return stored;

    // Check system preference
    if (window.matchMedia('(prefers-color-scheme: dark)').matches) {
      return 'dark';
    }
    return 'light';
  }

  function setTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem(THEME_KEY, theme);
    updateThemeToggle(theme);
  }

  function updateThemeToggle(theme) {
    const toggle = document.querySelector('.theme-toggle');
    if (!toggle) return;

    const icon = toggle.querySelector('.theme-toggle-icon');
    const text = toggle.querySelector('.theme-toggle-text');

    if (theme === 'dark') {
      if (icon) icon.textContent = '☀️';
      if (text) text.textContent = 'Light';
    } else {
      if (icon) icon.textContent = '🌙';
      if (text) text.textContent = 'Dark';
    }
  }

  function toggleTheme() {
    const current = document.documentElement.getAttribute('data-theme') || 'light';
    const next = current === 'dark' ? 'light' : 'dark';
    setTheme(next);
  }

  // Initialize theme
  function initTheme() {
    setTheme(getPreferredTheme());

    // Listen for system theme changes
    window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
      if (!localStorage.getItem(THEME_KEY)) {
        setTheme(e.matches ? 'dark' : 'light');
      }
    });

    // Theme toggle button
    const toggle = document.querySelector('.theme-toggle');
    if (toggle) {
      toggle.addEventListener('click', toggleTheme);
    }
  }

  // ============================================
  // Mobile Navigation
  // ============================================

  function initMobileNav() {
    const sidebar = document.querySelector('.sidebar');
    const toggle = document.querySelector('.mobile-menu-toggle');
    const overlay = document.querySelector('.overlay');

    if (!sidebar || !toggle) return;

    function openSidebar() {
      sidebar.classList.add('open');
      if (overlay) overlay.classList.add('active');
      document.body.style.overflow = 'hidden';
    }

    function closeSidebar() {
      sidebar.classList.remove('open');
      if (overlay) overlay.classList.remove('active');
      document.body.style.overflow = '';
    }

    toggle.addEventListener('click', () => {
      if (sidebar.classList.contains('open')) {
        closeSidebar();
      } else {
        openSidebar();
      }
    });

    if (overlay) {
      overlay.addEventListener('click', closeSidebar);
    }

    // Close on nav link click (mobile)
    const navLinks = sidebar.querySelectorAll('.nav-link');
    navLinks.forEach(link => {
      link.addEventListener('click', () => {
        if (window.innerWidth <= 768) {
          closeSidebar();
        }
      });
    });
  }

  // ============================================
  // Active Navigation Tracking
  // ============================================

  function initActiveNav() {
    const sections = document.querySelectorAll('.section[id]');
    const navLinks = document.querySelectorAll('.nav-link');

    if (sections.length === 0) return;

    function updateActiveNav() {
      const scrollPos = window.scrollY + 100;

      let currentSection = '';

      sections.forEach(section => {
        const sectionTop = section.offsetTop;
        const sectionHeight = section.offsetHeight;

        if (scrollPos >= sectionTop && scrollPos < sectionTop + sectionHeight) {
          currentSection = section.getAttribute('id');
        }
      });

      navLinks.forEach(link => {
        link.classList.remove('active');
        if (link.getAttribute('href') === '#' + currentSection) {
          link.classList.add('active');
        }
      });
    }

    window.addEventListener('scroll', updateActiveNav);
    updateActiveNav();
  }

  // ============================================
  // Search Functionality
  // ============================================

  function initSearch() {
    const searchInput = document.querySelector('.search-input');
    if (!searchInput) return;

    const searchableElements = document.querySelectorAll('h1, h2, h3, p, li, td');

    searchInput.addEventListener('input', (e) => {
      const query = e.target.value.toLowerCase().trim();

      if (query.length < 2) {
        searchableElements.forEach(el => {
          el.style.backgroundColor = '';
        });
        return;
      }

      searchableElements.forEach(el => {
        const text = el.textContent.toLowerCase();
        if (text.includes(query)) {
          el.style.backgroundColor = 'var(--accent-light)';
        } else {
          el.style.backgroundColor = '';
        }
      });
    });

    // Keyboard shortcut (Ctrl+K or Cmd+K)
    document.addEventListener('keydown', (e) => {
      if ((e.ctrlKey || e.metaKey) && e.key === 'k') {
        e.preventDefault();
        searchInput.focus();
      }

      // Escape to clear
      if (e.key === 'Escape' && document.activeElement === searchInput) {
        searchInput.value = '';
        searchInput.dispatchEvent(new Event('input'));
        searchInput.blur();
      }
    });
  }

  // ============================================
  // Smooth Scroll
  // ============================================

  function initSmoothScroll() {
    document.querySelectorAll('a[href^="#"]').forEach(anchor => {
      anchor.addEventListener('click', function(e) {
        const targetId = this.getAttribute('href');
        if (targetId === '#') return;

        const target = document.querySelector(targetId);
        if (target) {
          e.preventDefault();
          target.scrollIntoView({
            behavior: 'smooth',
            block: 'start'
          });

          // Update URL without jumping
          history.pushState(null, null, targetId);
        }
      });
    });
  }

  // ============================================
  // Code Block Copy
  // ============================================

  function initCodeCopy() {
    document.querySelectorAll('pre').forEach(pre => {
      const wrapper = document.createElement('div');
      wrapper.style.position = 'relative';

      const button = document.createElement('button');
      button.className = 'btn btn-secondary';
      button.style.cssText = 'position: absolute; top: 8px; right: 8px; padding: 4px 8px; font-size: 0.75rem;';
      button.textContent = 'Copy';

      button.addEventListener('click', async () => {
        const code = pre.querySelector('code');
        const text = code ? code.textContent : pre.textContent;

        try {
          await navigator.clipboard.writeText(text);
          button.textContent = 'Copied!';
          setTimeout(() => {
            button.textContent = 'Copy';
          }, 2000);
        } catch (err) {
          button.textContent = 'Failed';
          setTimeout(() => {
            button.textContent = 'Copy';
          }, 2000);
        }
      });

      pre.parentNode.insertBefore(wrapper, pre);
      wrapper.appendChild(pre);
      wrapper.appendChild(button);
    });
  }

  // ============================================
  // Table of Contents Generator
  // ============================================

  function generateTOC() {
    const tocContainer = document.querySelector('.toc');
    if (!tocContainer) return;

    const headings = document.querySelectorAll('.content h2, .content h3');

    if (headings.length === 0) return;

    const toc = document.createElement('ul');
    toc.className = 'nav-links';

    headings.forEach(heading => {
      // Ensure heading has an id
      if (!heading.id) {
        heading.id = heading.textContent
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, '-')
          .replace(/(^-|-$)/g, '');
      }

      const li = document.createElement('li');
      const a = document.createElement('a');
      a.className = 'nav-link';
      a.href = '#' + heading.id;
      a.textContent = heading.textContent;

      if (heading.tagName === 'H3') {
        a.style.paddingLeft = '24px';
        a.style.fontSize = '0.85rem';
      }

      li.appendChild(a);
      toc.appendChild(li);
    });

    tocContainer.appendChild(toc);
  }

  // ============================================
  // Collapsible Sections
  // ============================================

  function initCollapsible() {
    document.querySelectorAll('.collapsible-trigger').forEach(trigger => {
      trigger.addEventListener('click', () => {
        const content = trigger.nextElementSibling;
        const isOpen = content.style.maxHeight;

        if (isOpen) {
          content.style.maxHeight = null;
          trigger.classList.remove('open');
        } else {
          content.style.maxHeight = content.scrollHeight + 'px';
          trigger.classList.add('open');
        }
      });
    });
  }

  // ============================================
  // Animate on Scroll
  // ============================================

  function initAnimations() {
    const observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          entry.target.classList.add('animate-in');
          observer.unobserve(entry.target);
        }
      });
    }, {
      threshold: 0.1,
      rootMargin: '0px 0px -50px 0px'
    });

    document.querySelectorAll('.card, .feature-card, .alert').forEach(el => {
      el.style.opacity = '0';
      observer.observe(el);
    });
  }

  // ============================================
  // Initialize All
  // ============================================

  function init() {
    initTheme();
    initMobileNav();
    initActiveNav();
    initSearch();
    initSmoothScroll();
    initCodeCopy();
    generateTOC();
    initCollapsible();
    initAnimations();

    console.log('Marcha Documentation initialized');
  }

  // Run on DOM ready
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
