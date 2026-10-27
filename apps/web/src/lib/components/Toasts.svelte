<script lang="ts">
  import { t } from '$lib/i18n';
  import { removeToast, toasts } from '$lib/toast.svelte';
</script>

<div class="toasts">
  {#each toasts as toast (toast.id)}
    <div class="toast {toast.type}" role="alert">
      <span>{toast.message}</span>
      <button onclick={() => removeToast(toast.id)} aria-label={t().close}>×</button>
    </div>
  {/each}
</div>

<style>
  .toasts {
    position: fixed;
    z-index: 60;
    right: 1rem;
    bottom: 1rem;
    left: 1rem;
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    gap: 0.5rem;
    pointer-events: none;
  }
  .toast {
    display: flex;
    gap: 0.75rem;
    align-items: center;
    max-width: 400px;
    padding: 0.7rem 1rem;
    border: 1px solid var(--border);
    border-radius: var(--radius);
    background: var(--surface);
    box-shadow: 0 8px 24px rgb(0 0 0 / 0.12);
    pointer-events: auto;
  }
  .error {
    border-color: var(--error);
  }
  button {
    border: none;
    background: none;
    color: var(--muted);
    font-size: 1.2rem;
    cursor: pointer;
  }
</style>
