1;
clc;
clear;
close all;

pkg load io;

function f = weibull3_pdf(x, gamma, alpha, beta)
  x = x(:);
  f = zeros(size(x));

  if alpha <= 0 || beta <= 0
    f(:) = NaN;
    return;
  end

  valid = (x > gamma);
  xv = x(valid);

  z = (xv - gamma) ./ alpha;
  f(valid) = (beta ./ alpha) .* (z.^(beta - 1)) .* exp(-(z.^beta));
end

function F = weibull3_cdf(x, gamma, alpha, beta)
  x = x(:);
  F = zeros(size(x));

  if alpha <= 0 || beta <= 0
    F(:) = NaN;
    return;
  end

  valid = (x > gamma);
  xv = x(valid);

  z = (xv - gamma) ./ alpha;
  F(valid) = 1 - exp(-(z.^beta));
end

function q = weibull3_inv(p, gamma, alpha, beta)
  p = p(:);
  q = gamma + alpha .* ((-log(1 - p)).^(1 ./ beta));
end

function nll = weibull3_nll(params, datos)
  gamma = params(1);
  alpha = params(2);
  beta  = params(3);

  if alpha <= 0 || beta <= 0
    nll = 1e20;
    return;
  end

  datos = datos(:);

  if any(datos <= gamma)
    nll = 1e20;
    return;
  end

  z = (datos - gamma) ./ alpha;

  if any(z <= 0)
    nll = 1e20;
    return;
  end

  logf = log(beta) - log(alpha) + (beta - 1).*log(z) - z.^beta;
  nll = -sum(logf);
end

filename = 'Entregas Historicas.xlsx';

tributarios = {
    'Conchos'
    'Vacas'
    'San Diego'
    'San Rodrigo'
    'Escondido'
    'Salado'
};

disp('Tributarios disponibles:');
for j = 1:length(tributarios)
    fprintf('%d. %s\n', j, tributarios{j});
end

idx = input('Selecciona el nˆymero del tributario a analizar: ');
nombre_hoja = tributarios{idx};


[num, txt, raw] = xlsread(filename, nombre_hoja);

bloque = raw(2:end, 2:end);

[nr, nc] = size(bloque);
matriz_entregas = NaN(nr, nc);

for i = 1:nr
  for j = 1:nc
    val = bloque{i,j};
    if isnumeric(val) && isscalar(val)
      matriz_entregas(i,j) = val;
    end
  end
end

datos = max(matriz_entregas, [], 1);
datos = datos(:);
datos = datos(~isnan(datos));
datos = datos(datos > 0);
datos = sort(datos(:));

N = length(datos);

fprintf('\nDiagnˆustico:\n');
disp(datos(1:min(10,end))');

gamma0 = min(datos) - 0.05 * std(datos);
alpha0 = std(datos);
beta0  = 2;

params0 = [gamma0, alpha0, beta0];

params_hat = fminsearch(@(par) weibull3_nll(par, datos), params0);

gamma_hat = params_hat(1);
alpha_hat = params_hat(2);
beta_hat  = params_hat(3);

fprintf('\nParˆhmetros Weibull 3P:\n');
fprintf('gamma: %.6f\n', gamma_hat);
fprintf('alpha: %.6f\n', alpha_hat);
fprintf('beta : %.6f\n\n', beta_hat);

x = linspace(min(datos)*0.8, max(datos)*1.3, 1000);
x = x(:);

pdf_w3 = weibull3_pdf(x, gamma_hat, alpha_hat, beta_hat);
F_teo = weibull3_cdf(x, gamma_hat, alpha_hat, beta_hat);

F_emp = (1:N)'/(N+1);

p = ((1:N)' - 0.5)/N;
q_teo = weibull3_inv(p, gamma_hat, alpha_hat, beta_hat);

q_teo = q_teo(:);
datos = datos(:);

figure;
plot(q_teo, datos, 'bo'); hold on;

min_ref = min(min(q_teo), min(datos));
max_ref = max(max(q_teo), max(datos));

plot([min_ref max_ref],[min_ref max_ref],'r--');

title('QQ Weibull 3P');
grid on;

figure;
F_teo_datos = weibull3_cdf(datos, gamma_hat, alpha_hat, beta_hat);

F_teo_datos = F_teo_datos(:);
F_emp = F_emp(:);

plot(F_teo_datos, F_emp,'bo'); hold on;
plot([0 1],[0 1],'r--');

title('PP Weibull 3P');
grid on;
