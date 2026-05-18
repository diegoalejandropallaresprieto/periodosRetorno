1;
clc;
clear;
close all;

pkg load io;

function f = poisexp_pdf(x, lambda, beta, nmax)
  x = x(:);
  f = zeros(size(x));

  if lambda <= 0 || beta <= 0
    f(:) = NaN;
    return;
  end

  valid = x > 0;
  xv = x(valid);

  fx = zeros(size(xv));

  for n = 1:nmax
    w = exp(-lambda) * lambda^n / factorial(n);
    term = w .* (xv.^(n-1) .* exp(-xv./beta)) ./ (beta^n * gamma(n));
    fx = fx + term;
  end

  f(valid) = fx;
  f(~valid) = 0;
end
function F = poisexp_cdf(x, lambda, beta, nmax)
  x = x(:);
  F = zeros(size(x));

  if lambda <= 0 || beta <= 0
    F(:) = NaN;
    return;
  end

  for i = 1:length(x)
    xi = x(i);

    if xi <= 0
      F(i) = 0;
    else
      s = exp(-lambda);
      for n = 1:nmax
        w = exp(-lambda) * lambda^n / factorial(n);
        Fn = gammainc(xi / beta, n);
        s = s + w * Fn;
      end
      F(i) = min(max(s, 0), 1);
    end
  end
end

function q = poisexp_inv(p, lambda, beta, nmax)
  if p <= 0 || p >= 1 || lambda <= 0 || beta <= 0
    q = NaN;
    return;
  end

  x_inf = 0;
  x_sup = max(10 * lambda * beta, 1);

  while poisexp_cdf(x_sup, lambda, beta, nmax) < p
    x_sup = x_sup * 2;
    if x_sup > 1e8
      break;
    end
  end

  tol = 1e-6;
  while (x_sup - x_inf) > tol
    mid = (x_inf + x_sup) / 2;
    if poisexp_cdf(mid, lambda, beta, nmax) < p
      x_inf = mid;
    else
      x_sup = mid;
    end
  end

  q = (x_inf + x_sup) / 2;
end

function nll = poisexp_nll(params, datos, nmax)
  lambda = params(1);
  beta   = params(2);

  if lambda <= 0 || beta <= 0
    nll = 1e20;
    return;
  end

  datos = datos(:);
  f = poisexp_pdf(datos, lambda, beta, nmax);

  if any(f <= 0) || any(isnan(f)) || any(isinf(f))
    nll = 1e20;
    return;
  end

  nll = -sum(log(f));

  if isnan(nll) || isinf(nll)
    nll = 1e20;
  end
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

if isempty(raw)
    error('No se pudo leer la hoja "%s".', nombre_hoja);
end

bloque = raw(2:end, 2:end);

[nr, nc] = size(bloque);
matriz_entregas = NaN(nr, nc);

for i = 1:nr
    for j = 1:nc
        val = bloque{i,j};
        if isnumeric(val) && isscalar(val)
            matriz_entregas(i,j) = val;
        else
            matriz_entregas(i,j) = NaN;
        end
    end
end

datos = max(matriz_entregas, [], 1);
datos = datos(:);
datos = datos(~isnan(datos));
datos = datos(datos > 0);
datos = sort(datos(:));

N = length(datos);

if N < 5
    error('No hay suficientes mˆhximos anuales vˆhlidos en la hoja "%s".', nombre_hoja);
end

fprintf('\nDiagnˆustico de lectura:\n');
fprintf('Primeros 10 mˆhximos anuales:\n');
disp(datos(1:min(10,end))');

nmax = 30;

media = mean(datos);
varianza = var(datos);

lambda0 = max(media^2 / varianza, 0.5);
beta0   = max(varianza / media, 1e-3);

params0 = [lambda0, beta0];

options = optimset('MaxIter', 15000,
                   'MaxFunEvals', 30000,
                   'TolX', 1e-8,
                   'TolFun', 1e-8,
                   'Display', 'off');

params_hat = fminsearch(@(par) poisexp_nll(par, datos, nmax), params0, options);

lambda_hat = params_hat(1);
beta_hat   = params_hat(2);

fprintf('\nTributario analizado: %s\n', nombre_hoja);
fprintf('Nˆymero de mˆhximos anuales vˆhlidos: %d\n', N);
fprintf('Parˆhmetro lambda: %.6f\n', lambda_hat);
fprintf('Parˆhmetro beta: %.6f\n\n', beta_hat);


datos_desc = sort(datos, 'descend');
fprintf('  m  |  T_empirico  |  Max anual\n');
fprintf('---------------------------------\n');
for m = 1:N
    T_empirico = (N + 1) / m;
    P_actual = datos_desc(m);
    fprintf(' %3d |   %8.2f   | %10.4f\n', m, T_empirico, P_actual);
end

Tr = [2, 5, 10, 25, 50, 100];

fprintf('\nEstimaciones con distribuciˆun Poisson-Exponencial:\n');
for i = 1:length(Tr)
    Tret = Tr(i);
    P = (Tret - 1) / Tret;
    estimacion = poisexp_inv(P, lambda_hat, beta_hat, nmax);
    fprintf('Tr: %3d | Prob: %6.3f | Estimaciˆun: %10.4f\n', Tret, P, estimacion);
end

x = linspace(min(datos)*0.8, max(datos)*1.4, 600);
x = x(:);

pdf_pe = poisexp_pdf(x, lambda_hat, beta_hat, nmax);
F_teo = poisexp_cdf(x, lambda_hat, beta_hat, nmax);
F_emp = (1:N)' / (N + 1);
F_emp = F_emp(:);

figure;
[counts, centers] = hist(datos, 12);
counts = counts(:).';
centers = centers(:).';
bar(centers, counts);
hold on;

if length(centers) > 1
    bin_width = centers(2) - centers(1);
else
    bin_width = 1;
end

pdf_escalada = pdf_pe * N * bin_width;
plot(x, pdf_escalada, 'r', 'LineWidth', 2);

title(['Ajuste Poisson-Exponencial - ', nombre_hoja]);
xlabel('Mˆhximo anual');
ylabel('Frecuencia');
legend('Histograma', 'Poisson-Exponencial ajustada');
grid on;

figure;
plot(datos(:), F_emp(:), 'bo', 'MarkerSize', 5);
hold on;
plot(x(:), F_teo(:), 'r', 'LineWidth', 2);

title(['CDF Empˆqrica vs Poisson-Exponencial - ', nombre_hoja]);
xlabel('Mˆhximo anual');
ylabel('Probabilidad acumulada');
legend('Empˆqrica', 'Poisson-Exponencial');
grid on;

figure;
p = ((1:N)' - 0.5) / N;
p = p(:);
q_teo = zeros(N,1);

for i = 1:N
  q_teo(i) = poisexp_inv(p(i), lambda_hat, beta_hat, nmax);
end

q_teo = q_teo(:);
datos = datos(:);

plot(q_teo, datos, 'bo');
hold on;

min_ref = min(min(q_teo), min(datos));
max_ref = max(max(q_teo), max(datos));
plot([min_ref max_ref], [min_ref max_ref], 'r--');

title(['QQ-Plot Poisson-Exponencial - ', nombre_hoja]);
xlabel('Cuantiles teˆuricos');
ylabel('Datos observados');
grid on;

figure;
F_teo_datos = poisexp_cdf(datos, lambda_hat, beta_hat, nmax);

F_teo_datos = F_teo_datos(:);
F_emp = F_emp(:);

plot(F_teo_datos, F_emp, 'bo');
hold on;
plot([0 1], [0 1], 'r--');

title(['PP-Plot Poisson-Exponencial - ', nombre_hoja]);
xlabel('CDF teˆurica');
ylabel('CDF empˆqrica');
grid on;
