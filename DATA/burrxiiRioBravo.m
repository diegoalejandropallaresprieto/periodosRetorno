1;
clc;
clear;
close all;

pkg load io;
pkg load statistics;


nombre_modelo = 'Burr_XII';
filename = 'Entregas Historicas.xlsx';
Tr = [2, 5, 10, 25, 50, 100];


function f = burr12_pdf(x, gamma, alpha, c, k)
  x = x(:);
  f = zeros(size(x));

  if alpha <= 0 || c <= 0 || k <= 0
    f(:) = NaN;
    return;
  end

  valid = (x > gamma);
  xv = x(valid);
  z = (xv - gamma) ./ alpha;

  f(valid) = (c * k ./ alpha) .* (z.^(c - 1)) .* (1 + z.^c).^(-k - 1);
end

function F = burr12_cdf(x, gamma, alpha, c, k)
  x = x(:);
  F = zeros(size(x));

  if alpha <= 0 || c <= 0 || k <= 0
    F(:) = NaN;
    return;
  end

  valid = (x > gamma);
  xv = x(valid);
  z = (xv - gamma) ./ alpha;

  F(valid) = 1 - (1 + z.^c).^(-k);
  F(~valid) = 0;
end

function q = burr12_inv(p, gamma, alpha, c, k)
  p = p(:);
  q = NaN(size(p));

  valid = (p > 0) & (p < 1) & (alpha > 0) & (c > 0) & (k > 0);
  pv = p(valid);

  q(valid) = gamma + alpha .* (((1 - pv).^(-1 ./ k) - 1).^(1 ./ c));
end

function nll = burr12_nll(params, datos)
  gamma = params(1);
  alpha = params(2);
  c     = params(3);
  k     = params(4);

  if alpha <= 0 || c <= 0 || k <= 0
    nll = 1e20;
    return;
  end

  datos = datos(:);

  if any(datos <= gamma)
    nll = 1e20;
    return;
  end

  z = (datos - gamma) ./ alpha;

  if any(z <= 0) || any(isnan(z)) || any(isinf(z))
    nll = 1e20;
    return;
  end

  logf = log(c) + log(k) - log(alpha) + ...
         (c - 1).*log(z) - (k + 1).*log(1 + z.^c);

  nll = -sum(logf);

  if isnan(nll) || isinf(nll)
    nll = 1e20;
  end
end

function params = fit_model_bootstrap(datos_boot)
  gamma0 = min(datos_boot) - 0.05 * std(datos_boot);
  if gamma0 >= min(datos_boot)
      gamma0 = min(datos_boot) - 1;
  end

  alpha0 = std(datos_boot);
  if alpha0 <= 0
      alpha0 = max(mean(datos_boot), 1);
  end

  c0 = 2.0;
  k0 = 2.0;

  params0 = [gamma0, alpha0, c0, k0];

  options = optimset('MaxIter', 10000, ...
                     'MaxFunEvals', 20000, ...
                     'TolX', 1e-8, ...
                     'TolFun', 1e-8, ...
                     'Display', 'off');

  params = fminsearch(@(par) burr12_nll(par, datos_boot), params0, options);

  if any(isnan(params)) || any(isinf(params))
      params = [NaN NaN NaN NaN];
  end
end

function q = quantile_model_bootstrap(P, params)
  gamma_b = params(1);
  alpha_b = params(2);
  c_b     = params(3);
  k_b     = params(4);

  q = burr12_inv(P, gamma_b, alpha_b, c_b, k_b);
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

idx = input('Selecciona el n�ymero del tributario a analizar: ');
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
    error('No hay suficientes m�hximos anuales v�hlidos en la hoja "%s".', nombre_hoja);
end

fprintf('\nDiagn�ustico de lectura:\n');
fprintf('Primeros 10 m�hximos anuales:\n');
disp(datos(1:min(10,end))');

gamma0 = min(datos) - 0.05 * std(datos);
if gamma0 >= min(datos)
    gamma0 = min(datos) - 1;
end

alpha0 = std(datos);
if alpha0 <= 0
    alpha0 = max(mean(datos), 1);
end

c0 = 2.0;
k0 = 2.0;

params0 = [gamma0, alpha0, c0, k0];

options = optimset('MaxIter', 30000, ...
                   'MaxFunEvals', 60000, ...
                   'TolX', 1e-8, ...
                   'TolFun', 1e-8, ...
                   'Display', 'off');

params_hat = fminsearch(@(par) burr12_nll(par, datos), params0, options);

gamma_hat = params_hat(1);
alpha_hat = params_hat(2);
c_hat     = params_hat(3);
k_hat     = params_hat(4);

fprintf('\nTributario analizado: %s\n', nombre_hoja);
fprintf('N�ymero de m�hximos anuales v�hlidos: %d\n', N);
fprintf('Par�hmetro de ubicaci�un gamma: %.6f\n', gamma_hat);
fprintf('Par�hmetro de escala alpha: %.6f\n', alpha_hat);
fprintf('Par�hmetro de forma c: %.6f\n', c_hat);
fprintf('Par�hmetro de forma k: %.6f\n\n', k_hat);

datos_desc = sort(datos, 'descend');
fprintf('  m  |  T_empirico  |  Max anual\n');
fprintf('---------------------------------\n');
for m = 1:N
    T_empirico = (N + 1) / m;
    P_actual = datos_desc(m);
    fprintf(' %3d |   %8.2f   | %10.4f\n', m, T_empirico, P_actual);
end

estimaciones_base = NaN(1, length(Tr));

fprintf('\nEstimaciones con distribuci�un Burr tipo XII:\n');
for i = 1:length(Tr)
    Tret = Tr(i);
    P = (Tret - 1) / Tret;
    estimacion = burr12_inv(P, gamma_hat, alpha_hat, c_hat, k_hat);
    estimaciones_base(i) = estimacion;
    fprintf('Tr: %3d | Prob: %6.3f | Estimaci�un: %10.4f\n', Tret, P, estimacion);
end

nombre_archivo_estructural = ['incertidumbre_estructural_' nombre_hoja '.xlsx'];
guardar_resultado_estructural(nombre_archivo_estructural, nombre_modelo, Tr, estimaciones_base);

x_inf = max(gamma_hat + 1e-6, min(datos) * 0.8);
x_sup = max(datos) * 1.4;
x = linspace(x_inf, x_sup, 1400);
x = x(:);

pdf_burr = burr12_pdf(x, gamma_hat, alpha_hat, c_hat, k_hat);
F_teo = burr12_cdf(x, gamma_hat, alpha_hat, c_hat, k_hat);
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

pdf_escalada = pdf_burr * N * bin_width;
plot(x, pdf_escalada, 'r', 'LineWidth', 2);

title(['Ajuste Burr tipo XII - ', nombre_hoja]);
xlabel('M�hximo anual');
ylabel('Frecuencia');
legend('Histograma', 'Burr XII ajustada');
grid on;

figure;
plot(datos(:), F_emp(:), 'bo', 'MarkerSize', 5);
hold on;
plot(x(:), F_teo(:), 'r', 'LineWidth', 2);

title(['CDF Emp�qrica vs Burr tipo XII - ', nombre_hoja]);
xlabel('M�hximo anual');
ylabel('Probabilidad acumulada');
legend('Emp�qrica', 'Burr XII');
grid on;

figure;
p = ((1:N)' - 0.5) / N;
p = p(:);
q_teo = burr12_inv(p, gamma_hat, alpha_hat, c_hat, k_hat);
q_teo = q_teo(:);
datos = datos(:);

plot(q_teo, datos, 'bo');
hold on;

min_ref = min(min(q_teo), min(datos));
max_ref = max(max(q_teo), max(datos));
plot([min_ref max_ref], [min_ref max_ref], 'r--');

title(['QQ-Plot Burr tipo XII - ', nombre_hoja]);
xlabel('Cuantiles te�uricos');
ylabel('Datos observados');
grid on;

figure;
F_teo_datos = burr12_cdf(datos, gamma_hat, alpha_hat, c_hat, k_hat);
F_teo_datos = F_teo_datos(:);

plot(F_teo_datos, F_emp, 'bo');
hold on;
plot([0 1], [0 1], 'r--');

title(['PP-Plot Burr tipo XII - ', nombre_hoja]);
xlabel('CDF te�urica');
ylabel('CDF emp�qrica');
grid on;

n_boot = 200;
Tr_boot = Tr;
n_Tr = length(Tr_boot);

boot_est = NaN(n_boot, n_Tr);

for b = 1:n_boot
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

fprintf('\n==========================================\n');
fprintf('INCERTIDUMBRE MUESTRAL POR BOOTSTRAP\n');
fprintf('==========================================\n');
fprintf('Modelo: %s\n', nombre_modelo);
fprintf('Tributario: %s\n', nombre_hoja);
fprintf('N�ymero de remuestreos: %d\n\n', n_boot);

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
ylabel('Estimaci�un');
grid on;

fprintf('\n==========================================\n');
fprintf('SENSIBILIDAD PARAM�[TRICA (��5%%)\n');
fprintf('==========================================\n');

Tr_sens = [50, 100];

for tt = 1:length(Tr_sens)
    Tret = Tr_sens(tt);
    P = (Tret - 1) / Tret;

    q_base = burr12_inv(P, gamma_hat, alpha_hat, c_hat, k_hat);

    q_gamma_m = burr12_inv(P, gamma_hat*0.95, alpha_hat, c_hat, k_hat);
    q_gamma_p = burr12_inv(P, gamma_hat*1.05, alpha_hat, c_hat, k_hat);

    q_alpha_m = burr12_inv(P, gamma_hat, alpha_hat*0.95, c_hat, k_hat);
    q_alpha_p = burr12_inv(P, gamma_hat, alpha_hat*1.05, c_hat, k_hat);

    q_c_m = burr12_inv(P, gamma_hat, alpha_hat, c_hat*0.95, k_hat);
    q_c_p = burr12_inv(P, gamma_hat, alpha_hat, c_hat*1.05, k_hat);

    q_k_m = burr12_inv(P, gamma_hat, alpha_hat, c_hat, k_hat*0.95);
    q_k_p = burr12_inv(P, gamma_hat, alpha_hat, c_hat, k_hat*1.05);

    fprintf('\nTr = %d\n', Tret);
    fprintf('Base        : %10.4f\n', q_base);
    fprintf('gamma  -5%% : %10.4f | gamma  +5%% : %10.4f\n', q_gamma_m, q_gamma_p);
    fprintf('alpha  -5%% : %10.4f | alpha  +5%% : %10.4f\n', q_alpha_m, q_alpha_p);
    fprintf('c      -5%% : %10.4f | c      +5%% : %10.4f\n', q_c_m, q_c_p);
    fprintf('k      -5%% : %10.4f | k      +5%% : %10.4f\n', q_k_m, q_k_p);
end

fprintf('DETECCI�_N DE INESTABILIDAD DEL MODELO\n');

flag_inestable = 0;

if alpha_hat <= 1e-6 || c_hat <= 1e-6 || k_hat <= 1e-6
    fprintf('Advertencia: par�hmetros degenerados o cercanos a cero.\n');
    flag_inestable = 1;
end

if abs(gamma_hat) > 10 * max(datos)
    fprintf('Advertencia: par�hmetro gamma muy grande respecto a los datos.\n');
    flag_inestable = 1;
end

q100 = burr12_inv((100-1)/100, gamma_hat, alpha_hat, c_hat, k_hat);

if q100 > 5 * max(datos)
    fprintf('Advertencia: explosi�un de cuantiles en Tr altos.\n');
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

