import { createPaymentIntent, DOWNLOADS, parseAmount } from "./payments.js";

// The only release URL comes from payments.js. An amount never becomes a URL,
// HTML, or an arbitrary redirect. Paid intents go through the same-origin API.
export function setupDownloadFlow({ onOpen = () => {}, onSupportOpen = () => {} } = {}) {
  const dialog = document.querySelector("#download-dialog");
  const beta = document.querySelector("#beta-dialog");
  const trigger = document.querySelector("#download");
  const form = document.querySelector("#download-form");
  const amount = document.querySelector("#download-amount");
  const feedback = document.querySelector("#download-feedback");
  const free = document.querySelector("#download-free");
  const submit = document.querySelector("#download-submit");
  const macBetaDescription = document.querySelector("#mac-beta-description");
  const attempts = new Map();
  const busyForms = new Set();
  let activeTrigger = trigger;
  let betaTrigger = trigger;
  let selectedBuild = "download";
  async function checkout(intent, targetForm, feedbackElement) {
    if (busyForms.has(targetForm)) return;
    busyForms.add(targetForm);
    const controls = [...targetForm.querySelectorAll('button, input')];
    for (const control of controls) control.disabled = true;
    const signature = intent.context + ':' + intent.amountCents;
    if (!attempts.has(signature)) attempts.set(signature, crypto.randomUUID());
    message(feedbackElement, 'Opening secure checkout…');
    try {
      const response = await fetch('/api/checkout', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ amountCents: intent.amountCents, context: intent.context, requestId: attempts.get(signature) }),
        signal: AbortSignal.timeout(20000),
      });
      const result = await response.json().catch(() => null);
      if (!response.ok || !result?.url) throw Error(result?.error || 'Couldn’t open checkout. Please try again.');
      const url = new URL(result.url);
      if (url.protocol !== 'https:' || url.hostname !== 'polar.sh' || !url.pathname.startsWith('/checkout/') || url.username || url.password || url.port) throw Error('Couldn’t open secure checkout.');
      location.assign(url.href);
    } catch (error) {
      message(feedbackElement, error.name === 'TimeoutError' ? 'Checkout took too long. Reload to try again, or download for $0.' : error.message);
      if (targetForm === form) free.hidden = false;
    } finally {
      busyForms.delete(targetForm);
      for (const control of controls) control.disabled = false;
    }
  }
  const presets = [...dialog.querySelectorAll("[data-amount]")];

  function message(element, text) {
    element.textContent = text;
    element.hidden = !text;
  }
  function updateAmount() {
    const parsed = parseAmount(amount.value);
    amount.removeAttribute("aria-invalid");
    message(feedback, "");
    free.hidden = true;
    submit.textContent = parsed.ok && parsed.cents > 0
      ? "Support & download"
      : "Download Window Weather";
    for (const preset of presets)
      preset.setAttribute("aria-pressed", String(parsed.ok && parsed.cents === Number(preset.dataset.amount) * 100));
  }
  function download(build) {
    const link = document.createElement("a");
    link.href = DOWNLOADS[build];
    link.download = new URL(link.href).pathname.split("/").at(-1);
    document.body.append(link);
    link.click();
    link.remove();
    macBetaDescription.hidden = false;
    dialog.close();
    beta.showModal();
  }

  function showBuild(build) {
    selectedBuild = build;
    activeTrigger = trigger;
  }

  function openDownload(build) {
    if (dialog.open || beta.open || busyForms.has(form)) return;
    onOpen();
    showBuild(build);
    amount.value = amount.defaultValue;
    updateAmount();
    dialog.showModal();
    amount.focus({ preventScroll: true });
    amount.select();
  }
  trigger.addEventListener("click", () => openDownload("download"));
  for (const id of ["download-close", "download-cancel"])
    document.getElementById(id).addEventListener("click", () => dialog.close());
  dialog.addEventListener("close", () => {
    if (!beta.open) activeTrigger.focus({ preventScroll: true });
  });
  beta.addEventListener("close", () => betaTrigger.focus({ preventScroll: true }));
  amount.addEventListener("input", updateAmount);
  for (const preset of presets)
    preset.addEventListener("click", () => {
      amount.value = preset.dataset.amount;
      updateAmount();
    });
  free.addEventListener("click", () => download(selectedBuild));
  form.addEventListener("submit", (event) => {
    event.preventDefault();
    const build = "download";
    if (!Object.hasOwn(DOWNLOADS, build)) return;
    selectedBuild = build;
    const intent = createPaymentIntent(amount.value, build);
    if (!intent.ok) {
      amount.setAttribute("aria-invalid", "true");
      message(feedback, intent.error);
      amount.focus();
    } else if (intent.kind === "download") download(build);
    else {
      checkout(intent, form, feedback);
    }
  });

  const supportForm = document.querySelector("#support-form");
  const supportAmount = document.querySelector("#support-amount");
  const supportFeedback = document.querySelector("#support-feedback");
  supportAmount.addEventListener("input", () => {
    supportAmount.removeAttribute("aria-invalid");
    message(supportFeedback, "");
  });
  supportForm.addEventListener("submit", (event) => {
    event.preventDefault();
    const intent = createPaymentIntent(supportAmount.value, "support");
    if (!intent.ok) {
      supportAmount.setAttribute("aria-invalid", "true");
      message(supportFeedback, intent.error);
      supportAmount.focus();
    } else {
      if (intent.kind === "no-contribution")
        message(supportFeedback, "No contribution needed. Following along means a lot.");
      else checkout(intent, supportForm, supportFeedback);
    }
  });

  function startMenuCheckout() {
    if (location.hash !== "#drop-some-coins" || document.prerendering) return;
    // Consume the app's entry point so Back and reload cannot start another checkout.
    history.replaceState(history.state, "", location.pathname + location.search);
    onSupportOpen();
    supportAmount.value = "4.99";
    supportForm.requestSubmit();
  }
  window.addEventListener("hashchange", startMenuCheckout);
  document.addEventListener("prerenderingchange", startMenuCheckout, { once: true });
  startMenuCheckout();

  const returned = new URL(location.href);
  const reference = returned.searchParams.get('payment');
  if (reference || returned.searchParams.has('payment_cancelled')) {
    const build = returned.searchParams.get("build");
    openDownload(Object.hasOwn(DOWNLOADS, build) ? build : "download");
    amount.value = "0";
    updateAmount();
    if (!reference) {
      message(feedback, 'Checkout cancelled. No problem — Window Weather is still yours for $0.');
      history.replaceState(null, '', location.pathname + location.hash);
    } else {
      message(feedback, 'Confirming your payment…');
      (async () => {
        try {
          for (let i = 0; i < 5; i++) {
            const response = await fetch('/api/payment?ref=' + encodeURIComponent(reference), { cache: 'no-store', signal: AbortSignal.timeout(15000) });
            const result = await response.json();
            if (!response.ok) throw Error('We couldn’t confirm this payment. You can still download for $0.');
            if (result.status === 'succeeded') {
              if (Object.hasOwn(DOWNLOADS, result.context)) showBuild(result.context);
              message(feedback, result.amountCents > 0 ? 'Thank you for supporting Window Weather! Your download is ready below.' : 'Your download is ready.');
              history.replaceState(null, '', location.pathname + location.hash);
              return;
            }
            if (['failed', 'expired'].includes(result.status)) throw Error('This checkout didn’t complete. You can still download for $0.');
            await new Promise(resolve => setTimeout(resolve, 1500));
          }
          message(feedback, 'Your payment is still processing. Refresh to check again, or download Window Weather for $0 now.');
        } catch (error) { message(feedback, error.message); }
      })();
    }
  }
}
