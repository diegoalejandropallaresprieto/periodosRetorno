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


function y = lnorm3_pdf(x, gamma, mu, sigma)
  x = x(:);
  y = zeros(size(x));

  if sigma <= 0
    y(:) = NaN;
    return;
  end

  valid = (x > gamma);
  xv = x(valid);

  y(valid) = (1 ./ ((xv - gamma) .* sigma * sqrt(2*pi))) .* ...
             exp(-((log(xv - gamma) - mu).^2) ./ (2 * sigma^2));
end

function y = lnorm3_cdf(x, gamma, mu, sigma)
  x = x(:);
  y = zeros(size(x));

  if sigma <= 0
    y(:) = NaN;
    return;
  end

  valid = (x > gamma);
  xv = x(valid);

  z = (log(xv - gamma) - mu) ./ sigma;
  y(valid) = stdnorm_cdf(z);
  y(~valid) = 0;
end

function q = lnorm3_inv(p, gamma, mu, sigma)
  p = p(:);
  q = NaN(size(p));

  valid = (p > 0) & (p < 1) & (sigma > 0);
  pv = p(valid);

  z = stdnorm_inv(pv);
  q(valid) = gamma + exp(mu + sigma .* z);
end

function nll = lnorm3_nll(params, datos)
  gamma = params(1);
  mu    = params(2);
  sigma = params(3);

  if sigma <= 0
    nll = 1e20;
    return;
  end

  datos = datos(:);

  if any(datos <= gamma)
    nll = 1e20;
    return;
  end

  y = log(datos - gamma);

  nll = length(datos) * log(sigma) + ...
        sum(log(datos - gamma)) + ...
        0.5 * length(datos) * log(2*pi) + ...
        sum((y - mu).^2) / (2 * sigma^2);

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


[nr_raw, nc_raw] = size(raw);

if nr_raw < 3 || nc_raw < 3
    error('La hoja "%s" no tiene la estructura esperada.', nombre_hoja);
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


g0 = min(datos) - 0.1 * std(datos);
if g0 >= min(datos)
    g0 = min(datos) - 1;
end

y0 = log(datos - g0);
mu0 = mean(y0);
sigma0 = std(y0);

params0 = [g0, mu0, sigma0];

options = optimset('MaxIter', 10000, ...
                   'MaxFunEvals', 20000, ...
                   'TolX', 1e-8, ...
                   'TolFun', 1e-8, ...
                   'Display', 'off');

params_hat = fminsearch(@(par) lnorm3_nll(par, datos), params0, options);

gamma_hat = params_hat(1);
mu_hat    = params_hat(2);
sigma_hat = params_hat(3);

fprintf('\nTributario analizado: %s\n', nombre_hoja);
fprintf('Nˆymero de mˆhximos anuales vˆhlidos: %d\n', N);
fprintf('Parˆhmetro de ubicaciˆun gamma: %.6f\n', gamma_hat);
fprintf('Parˆhmetro logarˆqtmico mu: %.6f\n', mu_hat);
fprintf('Parˆhmetro logarˆqtmico sigma: %.6f\n\n', sigma_hat);

datos_desc = sort(datos, 'descend');
fprintf('  m  |  T_empirico  |  Max anual\n');
fprintf('---------------------------------\n');
for m = 1:N
    T_empirico = (N + 1) / m;
    P_actual = datos_desc(m);
    fprintf(' %3d |   %8.2f   | %10.4f\n', m, T_empirico, P_actual);
end

Tr = [2, 5, 10, 25, 50, 100];

fprintf('\nEstimaciones con distribuciˆun Log-Normal 3P:\n');
for i = 1:length(Tr)
    Tret = Tr(i);
    P = (Tret - 1) / Tret;
    estimacion = lnorm3_inv(P, gamma_hat, mu_hat, sigma_hat);
    fprintf('Tr: %3d | Prob: %6.3f | Estimaciˆun: %10.4f\n', Tret, P, estimacion);
end

x_inf = max(gamma_hat + 1e-6, min(datos) * 0.8);
x_sup = max(datos) * 1.3;
x = linspace(x_inf, x_sup, 1200);
x = x(:);

pdf_ln3 = lnorm3_pdf(x, gamma_hat, mu_hat, sigma_hat);
F_teo = lnorm3_cdf(x, gamma_hat, mu_hat, sigma_hat);
F_emp = ((1:N)' / (N + 1));
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

pdf_escalada = pdf_ln3 * N * bin_width;
plot(x, pdf_escalada, 'r', 'LineWidth', 2);

title(['Ajuste Log-Normal 3P - ', nombre_hoja]);
xlabel('Mˆhximo anual');
ylabel('Frecuencia');
legend('Histograma', 'Log-Normal 3P ajustada');
grid on;

figure;
plot(datos(:), F_emp(:), 'bo', 'MarkerSize', 5);
hold on;
plot(x(:), F_teo(:), 'r', 'LineWidth', 2);

title(['CDF Empˆqrica vs Log-Normal 3P - ', nombre_hoja]);
xlabel('Mˆhximo anual');
ylabel('Probabilidad acumulada');
legend('Empˆqrica', 'Log-Normal 3P');
grid on;


figure;
p = ((1:N)' - 0.5) / N;
p = p(:);

q_teo = lnorm3_inv(p, gamma_hat, mu_hat, sigma_hat);
q_teo = q_teo(:);
datos = datos(:);

plot(q_teo, datos, 'bo');
hold on;

min_ref = min(min(q_teo), min(datos));
max_ref = max(max(q_teo), max(datos));
plot([min_ref max_ref], [min_ref max_ref], 'r--');

title(['QQ-Plot Log-Normal 3P - ', nombre_hoja]);
xlabel('Cuantiles teˆuricos');
ylabel('Datos observados');
grid on;

figure;
F_teo_datos = lnorm3_cdf(datos, gamma_hat, mu_hat, sigma_hat);

F_teo_datos = F_teo_datos(:);
F_emp = F_emp(:);

plot(F_teo_datos, F_emp, 'bo');
hold on;
plot([0 1], [0 1], 'r--');

title(['PP-Plot Log-Normal 3P - ', nombre_hoja]);
xlabel('CDF teˆurica');
ylabel('CDF empˆqrica');
grid on;
