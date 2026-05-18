1;
clc;
clear;
close all;

pkg load io;

function val = stdnorm_cdf(z)
  val = 0.5 * (1 + erf(z / sqrt(2)));
end

function val = stdnorm_inv(p)
  val = sqrt(2) * erfinv(2*p - 1);
end


function g = sample_skewness(x)
  x = x(:);
  n = length(x);
  xm = mean(x);
  s = std(x);
  if s <= 0 || n < 3
    g = 0;
    return;
  end
  g = (n / ((n-1)*(n-2))) * sum(((x - xm) / s).^3);
end

function f = pearson3_pdf(y, mu, sigma, g)
  y = y(:);
  f = zeros(size(y));

  if sigma <= 0
    f(:) = NaN;
    return;
  end

  if abs(g) < 1e-8
    z = (y - mu) ./ sigma;
    f = (1 ./ (sigma * sqrt(2*pi))) .* exp(-0.5 * z.^2);
    return;
  end

  alpha = 4 / (g^2);
  beta  = sigma * abs(g) / 2;
  xi    = mu - 2 * sigma / g;

  if g > 0
    t = (y - xi) ./ beta;
    valid = t > 0;
    f(valid) = (1 ./ (beta * gamma(alpha))) .* (t(valid).^(alpha - 1)) .* exp(-t(valid));
  else
    t = (xi - y) ./ beta;
    valid = t > 0;
    f(valid) = (1 ./ (beta * gamma(alpha))) .* (t(valid).^(alpha - 1)) .* exp(-t(valid));
  end
end

function F = pearson3_cdf(y, mu, sigma, g)
  y = y(:);
  F = zeros(size(y));

  if sigma <= 0
    F(:) = NaN;
    return;
  end

  if abs(g) < 1e-8
    z = (y - mu) ./ sigma;
    F = stdnorm_cdf(z);
    return;
  end

  alpha = 4 / (g^2);
  beta  = sigma * abs(g) / 2;
  xi    = mu - 2 * sigma / g;

  if g > 0
    t = (y - xi) ./ beta;
    valid = t > 0;
    F(valid) = gammainc(t(valid), alpha);
    F(~valid) = 0;
  else
    t = (xi - y) ./ beta;
    valid = t > 0;
    F(valid) = 1 - gammainc(t(valid), alpha);
    F(~valid) = 1;
  end
end

function q = pearson3_inv(p, mu, sigma, g)
  if p <= 0 || p >= 1 || sigma <= 0
    q = NaN;
    return;
  end

  if abs(g) < 1e-8
    q = mu + sigma * stdnorm_inv(p);
    return;
  end

  y_inf = mu - 10*sigma;
  y_sup = mu + 10*sigma;

  while pearson3_cdf(y_inf, mu, sigma, g) > p
    y_inf = y_inf - 5*sigma;
  end

  while pearson3_cdf(y_sup, mu, sigma, g) < p
    y_sup = y_sup + 5*sigma;
  end

  tol = 1e-6;
  while (y_sup - y_inf) > tol
    mid = (y_inf + y_sup) / 2;
    Fmid = pearson3_cdf(mid, mu, sigma, g);

    if Fmid < p
      y_inf = mid;
    else
      y_sup = mid;
    end
  end

  q = (y_inf + y_sup) / 2;
end

function f = lp3_pdf(x, mu, sigma, g)
  x = x(:);
  f = zeros(size(x));
  valid = x > 0;
  y = log(x(valid));
  f(valid) = pearson3_pdf(y, mu, sigma, g) ./ x(valid);
end

function F = lp3_cdf(x, mu, sigma, g)
  x = x(:);
  F = zeros(size(x));
  valid = x > 0;
  y = log(x(valid));
  F(valid) = pearson3_cdf(y, mu, sigma, g);
end

function q = lp3_inv(p, mu, sigma, g)
  p = p(:);
  q = NaN(size(p));
  valid = (p > 0) & (p < 1);
  pv = p(valid);
  yq = zeros(size(pv));
  for ii = 1:length(pv)
    yq(ii) = pearson3_inv(pv(ii), mu, sigma, g);
  end
  q(valid) = exp(yq);
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


y = log(datos);

mu_lp3 = mean(y);
sigma_lp3 = std(y);
g_lp3 = sample_skewness(y);

fprintf('\nTributario analizado: %s\n', nombre_hoja);
fprintf('Nˆymero de mˆhximos anuales vˆhlidos: %d\n', N);
fprintf('Media logarˆqtmica mu: %.6f\n', mu_lp3);
fprintf('Desviaciˆun logarˆqtmica sigma: %.6f\n', sigma_lp3);
fprintf('Coeficiente de asimetrˆqa logarˆqtmica g: %.6f\n\n', g_lp3);

datos_desc = sort(datos, 'descend');
fprintf('  m  |  T_empirico  |  Max anual\n');
fprintf('---------------------------------\n');
for m = 1:N
    T_empirico = (N + 1) / m;
    P_actual = datos_desc(m);
    fprintf(' %3d |   %8.2f   | %10.4f\n', m, T_empirico, P_actual);
end

Tr = [2, 5, 10, 25, 50, 100];

fprintf('\nEstimaciones con distribuciˆun Log-Pearson tipo III:\n');
for i = 1:length(Tr)
    Tret = Tr(i);
    P = (Tret - 1) / Tret;
    estimacion = lp3_inv(P, mu_lp3, sigma_lp3, g_lp3);
    fprintf('Tr: %3d | Prob: %6.3f | Estimaciˆun: %10.4f\n', Tret, P, estimacion);
end

x = linspace(min(datos)*0.8, max(datos)*1.3, 1200);
x = x(:);

pdf_lp3 = lp3_pdf(x, mu_lp3, sigma_lp3, g_lp3);
F_teo = lp3_cdf(x, mu_lp3, sigma_lp3, g_lp3);
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

pdf_escalada = pdf_lp3 * N * bin_width;
plot(x, pdf_escalada, 'r', 'LineWidth', 2);

title(['Ajuste Log-Pearson III - ', nombre_hoja]);
xlabel('Mˆhximo anual');
ylabel('Frecuencia');
legend('Histograma', 'Log-Pearson III ajustada');
grid on;


figure;
plot(datos(:), F_emp(:), 'bo', 'MarkerSize', 5);
hold on;
plot(x(:), F_teo(:), 'r', 'LineWidth', 2);

title(['CDF Empˆqrica vs Log-Pearson III - ', nombre_hoja]);
xlabel('Mˆhximo anual');
ylabel('Probabilidad acumulada');
legend('Empˆqrica', 'Log-Pearson III');
grid on;

figure;
p = ((1:N)' - 0.5) / N;
p = p(:);
q_teo = lp3_inv(p, mu_lp3, sigma_lp3, g_lp3);
q_teo = q_teo(:);
datos = datos(:);

plot(q_teo, datos, 'bo');
hold on;

min_ref = min(min(q_teo), min(datos));
max_ref = max(max(q_teo), max(datos));
plot([min_ref max_ref], [min_ref max_ref], 'r--');

title(['QQ-Plot Log-Pearson III - ', nombre_hoja]);
xlabel('Cuantiles teˆuricos');
ylabel('Datos observados');
grid on;

figure;
F_teo_datos = lp3_cdf(datos, mu_lp3, sigma_lp3, g_lp3);
F_teo_datos = F_teo_datos(:);
F_emp = F_emp(:);

plot(F_teo_datos, F_emp, 'bo');
hold on;
plot([0 1], [0 1], 'r--');

title(['PP-Plot Log-Pearson III - ', nombre_hoja]);
xlabel('CDF teˆurica');
ylabel('CDF empˆqrica');
grid on;
