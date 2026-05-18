1;
clc;
clear;
close all;

pkg load io;

function y = gumbel_pdf(x, alpha, mu)
  x = x(:);
  z = (x - mu) ./ alpha;
  y = (1 ./ alpha) .* exp(-(z + exp(-z)));
end

function y = gumbel_cdf(x, alpha, mu)
  x = x(:);
  z = (x - mu) ./ alpha;
  y = exp(-exp(-z));
end

function q = gumbel_inv(p, alpha, mu)
  p = p(:);
  q = mu - alpha .* log(-log(p));
end

function y = tcev_pdf(x, p, a1, u1, a2, u2)
  x = x(:);
  y = (1 - p) .* gumbel_pdf(x, a1, u1) + p .* gumbel_pdf(x, a2, u2);
end

function y = tcev_cdf(x, p, a1, u1, a2, u2)
  x = x(:);
  y = (1 - p) .* gumbel_cdf(x, a1, u1) + p .* gumbel_cdf(x, a2, u2);
end

function q = tcev_inv(prob, p, a1, u1, a2, u2)
  if prob <= 0 || prob >= 1
    q = NaN;
    return;
  end

  x_inf = min(u1 - 10*a1, u2 - 10*a2);
  x_sup = max(u1 + 20*a1, u2 + 20*a2);

  while tcev_cdf(x_sup, p, a1, u1, a2, u2) < prob
    x_sup = x_sup * 2;
    if x_sup > 1e8
      break;
    end
  end

  tol = 1e-6;
  while (x_sup - x_inf) > tol
    mid = (x_inf + x_sup) / 2;
    if tcev_cdf(mid, p, a1, u1, a2, u2) < prob
      x_inf = mid;
    else
      x_sup = mid;
    end
  end

  q = (x_inf + x_sup) / 2;
end

function nll = tcev_nll(params, datos)
  p  = params(1);
  a1 = params(2);
  u1 = params(3);
  a2 = params(4);
  u2 = params(5);

  if p <= 0 || p >= 1 || a1 <= 0 || a2 <= 0
    nll = 1e20;
    return;
  end

  datos = datos(:);
  f = tcev_pdf(datos, p, a1, u1, a2, u2);

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

if N < 10
    error('No hay suficientes mˆhximos anuales vˆhlidos en la hoja "%s".', nombre_hoja);
end


media = mean(datos);
desvstd = std(datos);

a0 = (sqrt(6) / pi) * desvstd;
u0 = media - 0.5772156649 * a0;

p0  = 0.15;
a10 = 0.8 * a0;
u10 = u0;
a20 = 1.3 * a0;
u20 = u0 + 0.8 * desvstd;

params0 = [p0, a10, u10, a20, u20];

options = optimset('MaxIter', 10000, ...
                   'MaxFunEvals', 20000, ...
                   'TolX', 1e-8, ...
                   'TolFun', 1e-8, ...
                   'Display', 'off');

params_hat = fminsearch(@(par) tcev_nll(par, datos), params0, options);

p_hat  = params_hat(1);
a1_hat = params_hat(2);
u1_hat = params_hat(3);
a2_hat = params_hat(4);
u2_hat = params_hat(5);

fprintf('\nTributario analizado: %s\n', nombre_hoja);
fprintf('Nˆymero de mˆhximos anuales vˆhlidos: %d\n', N);
fprintf('Peso del componente extraordinario p: %.6f\n', p_hat);
fprintf('Componente 1 -> alpha1: %.6f | mu1: %.6f\n', a1_hat, u1_hat);
fprintf('Componente 2 -> alpha2: %.6f | mu2: %.6f\n\n', a2_hat, u2_hat);
datos_desc = sort(datos, 'descend');
fprintf('  m  |  T_empirico  |  Max anual\n');
fprintf('---------------------------------\n');
for m = 1:N
    T_empirico = (N + 1) / m;
    P_actual = datos_desc(m);
    fprintf(' %3d |   %8.2f   | %10.4f\n', m, T_empirico, P_actual);
end

Tr = [2, 5, 10, 25, 50, 100];

fprintf('\nEstimaciones con distribuciˆun TCEV:\n');
for i = 1:length(Tr)
    Tret = Tr(i);
    P = (Tret - 1) / Tret;
    estimacion = tcev_inv(P, p_hat, a1_hat, u1_hat, a2_hat, u2_hat);
    fprintf('Tr: %3d | Prob: %6.3f | Estimaciˆun: %10.4f\n', Tret, P, estimacion);
end


x = linspace(min(datos)*0.8, max(datos)*1.3, 1200);
x = x(:);

pdf_tcev = tcev_pdf(x, p_hat, a1_hat, u1_hat, a2_hat, u2_hat);
F_teo = tcev_cdf(x, p_hat, a1_hat, u1_hat, a2_hat, u2_hat);
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

pdf_escalada = pdf_tcev * N * bin_width;
plot(x, pdf_escalada, 'r', 'LineWidth', 2);

title(['Ajuste TCEV - ', nombre_hoja]);
xlabel('Mˆhximo anual');
ylabel('Frecuencia');
legend('Histograma', 'TCEV ajustada');
grid on;

figure;
plot(datos(:), F_emp(:), 'bo', 'MarkerSize', 5);
hold on;
plot(x(:), F_teo(:), 'r', 'LineWidth', 2);

title(['CDF Empˆqrica vs TCEV - ', nombre_hoja]);
xlabel('Mˆhximo anual');
ylabel('Probabilidad acumulada');
legend('Empˆqrica', 'TCEV');
grid on;

figure;
p_emp = ((1:N)' - 0.5) / N;
p_emp = p_emp(:);
q_teo = zeros(N,1);

for i = 1:N
    q_teo(i) = tcev_inv(p_emp(i), p_hat, a1_hat, u1_hat, a2_hat, u2_hat);
end

q_teo = q_teo(:);
datos = datos(:);

plot(q_teo, datos, 'bo');
hold on;

min_ref = min(min(q_teo), min(datos));
max_ref = max(max(q_teo), max(datos));
plot([min_ref max_ref], [min_ref max_ref], 'r--');

title(['QQ-Plot TCEV - ', nombre_hoja]);
xlabel('Cuantiles teˆuricos');
ylabel('Datos observados');
grid on;

figure;
F_teo_datos = tcev_cdf(datos, p_hat, a1_hat, u1_hat, a2_hat, u2_hat);
F_teo_datos = F_teo_datos(:);
F_emp = F_emp(:);

plot(F_teo_datos, F_emp, 'bo');
hold on;
plot([0 1], [0 1], 'r--');

title(['PP-Plot TCEV - ', nombre_hoja]);
xlabel('CDF teˆurica');
ylabel('CDF empˆqrica');
grid on;
