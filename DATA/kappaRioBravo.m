1;
clc;
clear;
close all;

pkg load io;
pkg load statistics;


nombre_modelo = 'Kappa_4P';
filename = 'Entregas Historicas.xlsx';
Tr = [2, 5, 10, 25, 50, 100];


function q = kappa4_inv(p, xi, alpha, k, h)
  p = p(:);
  q = NaN(size(p));

  if alpha <= 0
    return;
  end

  valid = (p > 0) & (p < 1);
  pv = p(valid);

  if abs(k) < 1e-8
    a = -log(pv);
  else
    a = (1 - pv.^k) ./ k;
  end

  if any(a <= 0)
    return;
  end

  if abs(h) < 1e-8
    b = -log(a);
  else
    b = (1 - a.^h) ./ h;
  end

  q(valid) = xi + alpha .* b;
end

function F = kappa4_cdf(x, xi, alpha, k, h)
  x = x(:);
  F = zeros(size(x));

  for i = 1:length(x)
    xv = x(i);

    p_inf = 1e-8;
    p_sup = 1 - 1e-8;

    q_inf = kappa4_inv(p_inf, xi, alpha, k, h);
    q_sup = kappa4_inv(p_sup, xi, alpha, k, h);

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

    tol = 1e-5;
    a = p_inf;
    b = p_sup;

    while (b - a) > tol
      m = (a + b) / 2;
      qm = kappa4_inv(m, xi, alpha, k, h);

      if qm < xv
        a = m;
      else
        b = m;
      end
    end

    F(i) = (a + b) / 2;
  end
end

function f = kappa4_pdf(x, xi, alpha, k, h)
  x = x(:);
  f = zeros(size(x));
  dx = 1e-4 * max(std(x), 1);

  for i = 1:length(x)
    x1 = x(i) - dx;
    x2 = x(i) + dx;

    F1 = kappa4_cdf(x1, xi, alpha, k, h);
    F2 = kappa4_cdf(x2, xi, alpha, k, h);

    f(i) = max((F2 - F1) / (2 * dx), 0);
  end
end

function err = kappa4_obj(params, datos)
  xi    = params(1);
  alpha = params(2);
  k     = params(3);
  h     = params(4);

  if alpha <= 0
    err = 1e20;
    return;
  end

  datos = datos(:);
  n = length(datos);
  p = ((1:n)' - 0.5) / n;

  q_teo = kappa4_inv(p, xi, alpha, k, h);
  q_teo = q_teo(:);

  if any(isnan(q_teo)) || any(isinf(q_teo))
    err = 1e20;
    return;
  end

  err = sum((datos - q_teo).^2);

  if isnan(err) || isinf(err)
    err = 1e20;
  end
end


function params = fit_model_bootstrap(datos_boot)
  xi0 = min(datos_boot) - 0.05 * std(datos_boot);
  alpha0 = std(datos_boot);
  k0 = 0.2;
  h0 = 0.2;

  if alpha0 <= 0
    alpha0 = max(mean(datos_boot), 1);
  end

  params0 = [xi0, alpha0, k0, h0];

  options = optimset('MaxIter', 3000,
                     'MaxFunEvals', 6000,
                     'TolX', 1e-6,
                     'TolFun', 1e-6,
                     'Display', 'off');

  params = fminsearch(@(par) kappa4_obj(par, datos_boot), params0, options);

  if any(isnan(params)) || any(isinf(params)) || params(2) <= 0
      params = [NaN NaN NaN NaN];
  end
end

function q = quantile_model_bootstrap(P, params)
  xi_b = params(1);
  alpha_b = params(2);
  k_b = params(3);
  h_b = params(4);
  q = kappa4_inv(P, xi_b, alpha_b, k_b, h_b);
end

function pval = percentile_manual(x, p)
  x = sort(x(:));
  n = length(x);

  if n == 0
      pval = NaN;
      return;
  end

  if p <= 0
      pval = x(1);
      return;
  end

  if p >= 100
      pval = x(end);
      return;
  end

  pos = 1 + (n - 1) * (p / 100);
  lo = floor(pos);
  hi = ceil(pos);

  if lo == hi
      pval = x(lo);
  else
      pval = x(lo) + (pos - lo) * (x(hi) - x(lo));
  end
end

function guardar_resultado_estructural(nombre_archivo, nombre_modelo, Tr, estimaciones)
  nueva_fila = cell(1, 2 + length(Tr));
  nueva_fila{1} = nombre_modelo;
  nueva_fila{2} = datestr(now, 'yyyy-mm-dd HH:MM:SS');
  for ii = 1:length(Tr)
    nueva_fila{2 + ii} = estimaciones(ii);
  end

  encabezado = cell(1, 2 + length(Tr));
  encabezado{1} = 'modelo';
  encabezado{2} = 'timestamp';
  for ii = 1:length(Tr)
    encabezado{2 + ii} = ['Tr_' num2str(Tr(ii))];
  end

  if exist(nombre_archivo, 'file') ~= 2
    out = [encabezado; nueva_fila];
  else
    [~, ~, raw_exist] = xlsread(nombre_archivo);
    out = [raw_exist; nueva_fila];
  end

  xlswrite(nombre_archivo, out);
end

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

[~, ~, raw] = xlsread(filename, nombre_hoja);

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


xi0 = min(datos) - 0.05 * std(datos);
alpha0 = std(datos);
k0 = 0.2;
h0 = 0.2;

if alpha0 <= 0
  alpha0 = max(mean(datos), 1);
end

params0 = [xi0, alpha0, k0, h0];

options = optimset('MaxIter', 8000,
                   'MaxFunEvals', 15000,
                   'TolX', 1e-6,
                   'TolFun', 1e-6,
                   'Display', 'off');

params_hat = fminsearch(@(par) kappa4_obj(par, datos), params0, options);

xi_hat    = params_hat(1);
alpha_hat = params_hat(2);
k_hat     = params_hat(3);
h_hat     = params_hat(4);

fprintf('\nTributario analizado: %s\n', nombre_hoja);
fprintf('Nˆymero de mˆhximos anuales vˆhlidos: %d\n', N);
fprintf('Parˆhmetro de ubicaciˆun xi: %.6f\n', xi_hat);
fprintf('Parˆhmetro de escala alpha: %.6f\n', alpha_hat);
fprintf('Parˆhmetro de forma k: %.6f\n', k_hat);
fprintf('Parˆhmetro de forma h: %.6f\n\n', h_hat);

datos_desc = sort(datos, 'descend');
fprintf('  m  |  T_empirico  |  Max anual\n');
fprintf('---------------------------------\n');
for m = 1:N
    T_empirico = (N + 1) / m;
    P_actual = datos_desc(m);
    fprintf(' %3d |   %8.2f   | %10.4f\n', m, T_empirico, P_actual);
end

estimaciones_base = NaN(1, length(Tr));

fprintf('\nEstimaciones con distribuciˆun Kappa 4P:\n');
for i = 1:length(Tr)
    Tret = Tr(i);
    P = (Tret - 1) / Tret;
    estimacion = kappa4_inv(P, xi_hat, alpha_hat, k_hat, h_hat);
    estimaciones_base(i) = estimacion;
    fprintf('Tr: %3d | Prob: %6.3f | Estimaciˆun: %10.4f\n', Tret, P, estimacion);
end

nombre_archivo_estructural = ['incertidumbre_estructural_' nombre_hoja '.xlsx'];
guardar_resultado_estructural(nombre_archivo_estructural, nombre_modelo, Tr, estimaciones_base);


fprintf('\n>>> GRAFICANDO CURVAS KAPPA...\n');

x_inf = min(datos) * 0.8;
x_sup = max(datos) * 1.4;
x = linspace(x_inf, x_sup, 250);
x = x(:);

pdf_kappa = kappa4_pdf(x, xi_hat, alpha_hat, k_hat, h_hat);
F_teo = kappa4_cdf(x, xi_hat, alpha_hat, k_hat, h_hat);
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

pdf_escalada = pdf_kappa * N * bin_width;
plot(x, pdf_escalada, 'r', 'LineWidth', 2);

title(['Ajuste Kappa 4P - ', nombre_hoja]);
xlabel('Mˆhximo anual');
ylabel('Frecuencia');
legend('Histograma', 'Kappa 4P ajustada');
grid on;

figure;
plot(datos(:), F_emp(:), 'bo', 'MarkerSize', 5);
hold on;
plot(x(:), F_teo(:), 'r', 'LineWidth', 2);

title(['CDF Empˆqrica vs Kappa 4P - ', nombre_hoja]);
xlabel('Mˆhximo anual');
ylabel('Probabilidad acumulada');
legend('Empˆqrica', 'Kappa 4P');
grid on;

figure;
p = ((1:N)' - 0.5) / N;
p = p(:);

q_teo = kappa4_inv(p, xi_hat, alpha_hat, k_hat, h_hat);
q_teo = q_teo(:);
datos = datos(:);

plot(q_teo, datos, 'bo');
hold on;

min_ref = min(min(q_teo), min(datos));
max_ref = max(max(q_teo), max(datos));
plot([min_ref max_ref], [min_ref max_ref], 'r--');

title(['QQ-Plot Kappa 4P - ', nombre_hoja]);
xlabel('Cuantiles teˆuricos');
ylabel('Datos observados');
grid on;

figure;
F_teo_datos = kappa4_cdf(datos, xi_hat, alpha_hat, k_hat, h_hat);
F_teo_datos = F_teo_datos(:);

plot(F_teo_datos, F_emp, 'bo');
hold on;
plot([0 1], [0 1], 'r--');

title(['PP-Plot Kappa 4P - ', nombre_hoja]);
xlabel('CDF teˆurica');
ylabel('CDF empˆqrica');
grid on;

fprintf('INCERTIDUMBRE MUESTRAL POR BOOTSTRAP\n');

n_boot = 40;
Tr_boot = Tr;
n_Tr = length(Tr_boot);

boot_est = NaN(n_boot, n_Tr);

for b = 1:n_boot
    fprintf('Bootstrap %d/%d\n', b, n_boot);

    idx_boot = randi(N, N, 1);
    datos_boot = datos(idx_boot);
    datos_boot = sort(datos_boot(:));

    params_boot = fit_model_bootstrap(datos_boot);

    if any(isnan(params_boot)) || any(isinf(params_boot))
        continue;
    end

    for t = 1:n_Tr
        Tret = Tr_boot(t);
        P = (Tret - 1) / Tret;
        q = quantile_model_bootstrap(P, params_boot);

        if ~isnan(q) && ~isinf(q)
            boot_est(b, t) = q;
        end
    end
end

fprintf('\nModelo: %s\n', nombre_modelo);
fprintf('Tributario: %s\n', nombre_hoja);
fprintf('Nˆymero de remuestreos: %d\n\n', n_boot);

fprintf(' Tr  |   Media   |   Std   |   P2.5   |   P97.5\n');
fprintf('---------------------------------------------------\n');

for t = 1:n_Tr
    vals = boot_est(:, t);
    vals = vals(~isnan(vals));

    if isempty(vals)
        fprintf('%3d |    NaN   |   NaN   |   NaN   |   NaN\n', Tr_boot(t));
    else
        media_boot = mean(vals);
        std_boot = std(vals);
        p025 = percentile_manual(vals, 2.5);
        p975 = percentile_manual(vals, 97.5);

        fprintf('%3d | %8.3f | %7.3f | %8.3f | %8.3f\n', ...
            Tr_boot(t), media_boot, std_boot, p025, p975);
    end
end

figure;
boxplot(boot_est, 'Labels', strtrim(cellstr(num2str(Tr_boot(:)))));
title(['Bootstrap - ', nombre_modelo, ' - ', nombre_hoja]);
xlabel('Periodo de retorno');
ylabel('Estimaciˆun');
grid on;

fprintf('SENSIBILIDAD PARAMˆ[TRICA (¡Ó5%%)\n');
Tr_sens = [50, 100];

for tt = 1:length(Tr_sens)
    Tret = Tr_sens(tt);
    P = (Tret - 1) / Tret;

    q_base = kappa4_inv(P, xi_hat, alpha_hat, k_hat, h_hat);

    q_xi_m = kappa4_inv(P, xi_hat*0.95, alpha_hat, k_hat, h_hat);
    q_xi_p = kappa4_inv(P, xi_hat*1.05, alpha_hat, k_hat, h_hat);

    q_alpha_m = kappa4_inv(P, xi_hat, alpha_hat*0.95, k_hat, h_hat);
    q_alpha_p = kappa4_inv(P, xi_hat, alpha_hat*1.05, k_hat, h_hat);

    q_k_m = kappa4_inv(P, xi_hat, alpha_hat, k_hat*0.95, h_hat);
    q_k_p = kappa4_inv(P, xi_hat, alpha_hat, k_hat*1.05, h_hat);

    q_h_m = kappa4_inv(P, xi_hat, alpha_hat, k_hat, h_hat*0.95);
    q_h_p = kappa4_inv(P, xi_hat, alpha_hat, k_hat, h_hat*1.05);

    fprintf('\nTr = %d\n', Tret);
    fprintf('Base        : %10.4f\n', q_base);
    fprintf('xi    -5%%  : %10.4f | xi    +5%%  : %10.4f\n', q_xi_m, q_xi_p);
    fprintf('alpha -5%%  : %10.4f | alpha +5%%  : %10.4f\n', q_alpha_m, q_alpha_p);
    fprintf('k     -5%%  : %10.4f | k     +5%%  : %10.4f\n', q_k_m, q_k_p);
    fprintf('h     -5%%  : %10.4f | h     +5%%  : %10.4f\n', q_h_m, q_h_p);
end

fprintf('DETECCIˆ_N DE INESTABILIDAD DEL MODELO\n');

flag_inestable = 0;

if alpha_hat <= 1e-6
    fprintf('Advertencia: alpha degenerado o cercano a cero.\n');
    flag_inestable = 1;
end

if abs(k_hat) > 5 || abs(h_hat) > 5
    fprintf('Advertencia: parˆhmetros de forma demasiado extremos.\n');
    flag_inestable = 1;
end

q100 = kappa4_inv((100-1)/100, xi_hat, alpha_hat, k_hat, h_hat);

if q100 > 5 * max(datos)
    fprintf('Advertencia: explosiˆun de cuantiles en Tr altos.\n');
    flag_inestable = 1;
end

boot_tr100 = boot_est(:, Tr_boot == 100);
boot_tr100 = boot_tr100(~isnan(boot_tr100));

if ~isempty(boot_tr100)
    cv_tr100 = std(boot_tr100) / mean(boot_tr100);
    fprintf('CV bootstrap para Tr=100: %.4f\n', cv_tr100);

    if cv_tr100 > 0.30
        fprintf('Advertencia: alta variabilidad bootstrap en Tr=100.\n');
        flag_inestable = 1;
    end
end

if flag_inestable == 0
    fprintf('No se detectaron se~nales fuertes de inestabilidad.\n');
else
    fprintf('El modelo presenta se~nales de inestabilidad o alta incertidumbre.\n');
end
