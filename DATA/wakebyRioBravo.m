1;
clc;
clear;
close all;

pkg load io;

function q = wakeby_inv(p, xi, alpha, beta, gamma, delta)
  p = p(:);
  q = NaN(size(p));

  if alpha <= 0 || gamma < 0
    return;
  end

  valid = (p > 0) & (p < 1);
  pv = p(valid);
  u = 1 - pv;

  if abs(beta) < 1e-8
    term1 = -alpha .* log(u);
  else
    term1 = (alpha ./ beta) .* (1 - u.^beta);
  end

  if abs(delta) < 1e-8
    term2 = -gamma .* log(u);
  else
    term2 = (gamma ./ delta) .* (1 - u.^(-delta));
  end

  q(valid) = xi + term1 - term2;
end

function F = wakeby_cdf(x, xi, alpha, beta, gamma, delta)
  x = x(:);
  F = zeros(size(x));

  for i = 1:length(x)
    xv = x(i);

    p_inf = 1e-8;
    p_sup = 1 - 1e-8;

    q_inf = wakeby_inv(p_inf, xi, alpha, beta, gamma, delta);
    q_sup = wakeby_inv(p_sup, xi, alpha, beta, gamma, delta);

    if isnan(q_inf) || isnan(q_sup)
      F(i) = NaN;
      continue;
    end

    if xv <= q_inf
      F(i) = 0;
      continue;
    end

    if xv >= q_sup
      F(i) = 1;
      continue;
    end

    a = p_inf;
    b = p_sup;
    tol = 1e-6;

    while (b - a) > tol
      m = (a + b) / 2;
      qm = wakeby_inv(m, xi, alpha, beta, gamma, delta);

      if qm < xv
        a = m;
      else
        b = m;
      end
    end

    F(i) = (a + b) / 2;
  end
end


function f = wakeby_pdf(x, xi, alpha, beta, gamma, delta)
  x = x(:);
  f = zeros(size(x));
  dx = 1e-4 * max(std(x), 1);

  for i = 1:length(x)
    x1 = x(i) - dx;
    x2 = x(i) + dx;

    F1 = wakeby_cdf(x1, xi, alpha, beta, gamma, delta);
    F2 = wakeby_cdf(x2, xi, alpha, beta, gamma, delta);

    f(i) = max((F2 - F1) / (2 * dx), 0);
  end
end

function err = wakeby_obj(params, datos)
  xi    = params(1);
  alpha = params(2);
  beta  = params(3);
  gamma = params(4);
  delta = params(5);

  if alpha <= 0 || gamma < 0
    err = 1e20;
    return;
  end

  datos = datos(:);
  n = length(datos);
  p = ((1:n)' - 0.5) / n;

  q_teo = wakeby_inv(p, xi, alpha, beta, gamma, delta);
  q_teo = q_teo(:);

  if any(isnan(q_teo)) || any(isinf(q_teo))
    err = 1e20;
    return;
  end

  if any(diff(q_teo) <= 0)
    err = 1e20;
    return;
  end

  err = sum((datos - q_teo).^2);

  if isnan(err) || isinf(err)
    err = 1e20;
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

xi0    = min(datos) - 0.05 * std(datos);
alpha0 = std(datos);
beta0  = 0.2;
gamma0 = 0.2 * std(datos);
delta0 = 0.1;

if alpha0 <= 0
  alpha0 = max(mean(datos), 1);
end

if gamma0 < 0
  gamma0 = 0;
end

params0 = [xi0, alpha0, beta0, gamma0, delta0];

options = optimset('MaxIter', 20000, ...
                   'MaxFunEvals', 40000, ...
                   'TolX', 1e-8, ...
                   'TolFun', 1e-8, ...
                   'Display', 'off');

params_hat = fminsearch(@(par) wakeby_obj(par, datos), params0, options);

xi_hat    = params_hat(1);
alpha_hat = params_hat(2);
beta_hat  = params_hat(3);
gamma_hat = params_hat(4);
delta_hat = params_hat(5);

fprintf('\nTributario analizado: %s\n', nombre_hoja);
fprintf('Nˆymero de mˆhximos anuales vˆhlidos: %d\n', N);
fprintf('Parˆhmetro de ubicaciˆun xi: %.6f\n', xi_hat);
fprintf('Parˆhmetro alpha: %.6f\n', alpha_hat);
fprintf('Parˆhmetro beta: %.6f\n', beta_hat);
fprintf('Parˆhmetro gamma: %.6f\n', gamma_hat);
fprintf('Parˆhmetro delta: %.6f\n\n', delta_hat);

% ==========================================
% Tabla empˆqrica
% ==========================================
datos_desc = sort(datos, 'descend');
fprintf('  m  |  T_empirico  |  Max anual\n');
fprintf('---------------------------------\n');
for m = 1:N
    T_empirico = (N + 1) / m;
    P_actual = datos_desc(m);
    fprintf(' %3d |   %8.2f   | %10.4f\n', m, T_empirico, P_actual);
end

% ==========================================
% Estimaciones para tiempos de retorno fijos
% ==========================================
Tr = [2, 5, 10, 25, 50, 100];

fprintf('\nEstimaciones con distribuciˆun Wakeby:\n');
for i = 1:length(Tr)
    Tret = Tr(i);
    P = (Tret - 1) / Tret;
    estimacion = wakeby_inv(P, xi_hat, alpha_hat, beta_hat, gamma_hat, delta_hat);
    fprintf('Tr: %3d | Prob: %6.3f | Estimaciˆun: %10.4f\n', Tret, P, estimacion);
end

% ==========================================
% Curvas teˆuricas
% ==========================================
x_inf = min(datos) * 0.8;
x_sup = max(datos) * 1.5;
x = linspace(x_inf, x_sup, 500);
x = x(:);

pdf_wake = wakeby_pdf(x, xi_hat, alpha_hat, beta_hat, gamma_hat, delta_hat);
F_teo = wakeby_cdf(x, xi_hat, alpha_hat, beta_hat, gamma_hat, delta_hat);
F_emp = (1:N)' / (N + 1);
F_emp = F_emp(:);

% ==========================================
% Histograma + PDF
% ==========================================
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

pdf_escalada = pdf_wake * N * bin_width;
plot(x, pdf_escalada, 'r', 'LineWidth', 2);

title(['Ajuste Wakeby - ', nombre_hoja]);
xlabel('Mˆhximo anual');
ylabel('Frecuencia');
legend('Histograma', 'Wakeby ajustada');
grid on;

% ==========================================
% CDF empˆqrica vs teˆurica
% ==========================================
figure;
plot(datos(:), F_emp(:), 'bo', 'MarkerSize', 5);
hold on;
plot(x(:), F_teo(:), 'r', 'LineWidth', 2);

title(['CDF Empˆqrica vs Wakeby - ', nombre_hoja]);
xlabel('Mˆhximo anual');
ylabel('Probabilidad acumulada');
legend('Empˆqrica', 'Wakeby');
grid on;

% ==========================================
% QQ-Plot
% ==========================================
figure;
p = ((1:N)' - 0.5) / N;
p = p(:);

q_teo = wakeby_inv(p, xi_hat, alpha_hat, beta_hat, gamma_hat, delta_hat);
q_teo = q_teo(:);
datos = datos(:);

plot(q_teo, datos, 'bo');
hold on;

min_ref = min(min(q_teo), min(datos));
max_ref = max(max(q_teo), max(datos));
plot([min_ref max_ref], [min_ref max_ref], 'r--');

title(['QQ-Plot Wakeby - ', nombre_hoja]);
xlabel('Cuantiles teˆuricos');
ylabel('Datos observados');
grid on;

% ==========================================
% PP-Plot
% ==========================================
figure;
F_teo_datos = wakeby_cdf(datos, xi_hat, alpha_hat, beta_hat, gamma_hat, delta_hat);
F_teo_datos = F_teo_datos(:);
F_emp = F_emp(:);

plot(F_teo_datos, F_emp, 'bo');
hold on;
plot([0 1], [0 1], 'r--');

title(['PP-Plot Wakeby - ', nombre_hoja]);
xlabel('CDF teˆurica');
ylabel('CDF empˆqrica');
grid on;


disp('Primeras 5x5 de matriz_entregas:');
disp(matriz_entregas(1:min(5,end), 1:min(5,end)));

datos = max(matriz_entregas, [], 1);
datos = datos(:);
datos = datos(~isnan(datos));
datos = datos(datos > 0);
datos = sort(datos(:));

disp('Primeros 10 datos finales:');
disp(datos(1:min(10,end))');
