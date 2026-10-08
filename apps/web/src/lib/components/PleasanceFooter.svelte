<script lang="ts">
  import { APP_BAND } from '@app/shared';
  import { openFeedback } from '$lib/feedback.svelte';
</script>

<footer>
  <a href="https://pleasance.org">ein Werkzeug von <span class="wordmark" role="img" aria-label="Pleasance"></span></a>
  <button type="button" class="feedback" onclick={() => openFeedback('idea')}>Feedback geben</button>
  <a class="legal" href="/impressum">Impressum</a>
  <a class="legal" href="/datenschutz">Datenschutz</a>
  <span class="band" aria-hidden="true"><span
    class="marker"
    style:left="{((APP_BAND.from - 1) / 6) * 100}%"
    style:width="{((APP_BAND.to - APP_BAND.from) / 6) * 100}%"
  ></span></span>
</footer>

<style>
  footer { display: flex; align-items: center; gap: 24px; padding: 22px 0; border-top: 1px solid var(--border); color: var(--text); font-size: 12px; }
  a { display: inline-flex; align-items: center; gap: 8px; text-decoration: none; white-space: nowrap; color: inherit; }
  .wordmark { width: 76px; height: 14px; background: currentColor; mask: url('/pleasance-wordmark.svg') left center / contain no-repeat; }
  .feedback { padding: 0; border: none; background: none; color: var(--accent); font-size: inherit; text-decoration: underline; text-underline-offset: 3px; }
  .legal { color: var(--muted); }
  .band { position: relative; width: 136px; height: 3px; margin-left: auto; border-radius: 2px; background: linear-gradient(rgb(0 0 0 / 0.55), rgb(0 0 0 / 0.55)), var(--spectrum); }
  .marker { position: absolute; top: -3px; min-width: 9px; height: 9px; border-radius: 5px; background: var(--gradient); box-shadow: 0 0 0 2px var(--bg); }
  @media(max-width: 650px) { footer { flex-wrap: wrap; gap: 12px 16px; font-size: 10px; } .wordmark { width: 68px; height: 13px; } .band { width: 95px; } }
</style>
