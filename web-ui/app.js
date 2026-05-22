const API_ENDPOINT = window.ENV_API_ENDPOINT || 'https://REPLACE_WITH_API_GATEWAY_URL/prod/environments';

const form        = document.getElementById('envForm');
const submitBtn   = document.getElementById('submitBtn');
const btnText     = submitBtn.querySelector('.btn-text');
const btnSpinner  = submitBtn.querySelector('.btn-spinner');
const errorBanner = document.getElementById('errorBanner');
const successBanner = document.getElementById('successBanner');
const previewName = document.getElementById('preview-name');

const teamInput    = document.getElementById('team');
const projectInput = document.getElementById('project');

function updatePreview() {
  const team    = teamInput.value.trim();
  const project = projectInput.value.trim();
  previewName.textContent = team && project ? `${team}-${project}-<id>` : '—';
}

teamInput.addEventListener('input', updatePreview);
projectInput.addEventListener('input', updatePreview);

function setLoading(loading) {
  submitBtn.disabled = loading;
  btnText.textContent = loading ? 'Requesting…' : 'Request Environment';
  btnSpinner.classList.toggle('hidden', !loading);
}

function showError(msg) {
  errorBanner.textContent = msg;
  errorBanner.classList.remove('hidden');
  successBanner.classList.add('hidden');
}

function showSuccess(envId) {
  successBanner.innerHTML = `
    Environment <strong>${envId}</strong> is being provisioned.
    You'll receive an email with your kubeconfig and dashboard link in ~5 minutes.
  `;
  successBanner.classList.remove('hidden');
  errorBanner.classList.add('hidden');
  form.reset();
  previewName.textContent = '—';
}

function validateField(input) {
  const valid = input.checkValidity();
  input.classList.toggle('invalid', !valid);
  return valid;
}

form.addEventListener('submit', async (e) => {
  e.preventDefault();

  errorBanner.classList.add('hidden');
  successBanner.classList.add('hidden');

  const fields = form.querySelectorAll('input, select');
  let allValid = true;
  fields.forEach(f => { if (!validateField(f)) allValid = false; });
  if (!allValid) {
    showError('Please fill in all required fields correctly.');
    return;
  }

  const payload = {
    team:         form.team.value.trim(),
    project:      form.project.value.trim(),
    owner_email:  form.owner_email.value.trim(),
    cpu_limit:    form.cpu_limit.value,
    memory_limit: form.memory_limit.value,
  };

  setLoading(true);
  try {
    const res = await fetch(API_ENDPOINT, {
      method:  'POST',
      headers: { 'Content-Type': 'application/json' },
      body:    JSON.stringify(payload),
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.message || `Request failed (${res.status})`);
    }

    const data = await res.json();
    showSuccess(data.env_id);
  } catch (err) {
    showError(err.message || 'An unexpected error occurred. Please try again.');
  } finally {
    setLoading(false);
  }
});

['team', 'project', 'owner_email'].forEach(id => {
  document.getElementById(id).addEventListener('blur', (e) => validateField(e.target));
});
