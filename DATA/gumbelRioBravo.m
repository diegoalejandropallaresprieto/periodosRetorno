1;
clc;
clear;
close all;

pkg load io;
pkg load statistics;

nombre_modelo = 'Gumbel_EV1';
filename = 'Entregas Historicas.xlsx';
Tr = [2, 5, 10, 25, 50, 100];

function f = gumbel_pdf(x, alpha, mu)
  x = x(:);
  z = (x - mu) ./ alpha;
  f = (1 ./ alpha) .* exp(-(z + exp(-z)));
end

function F = gumbel_cdf(x, alpha, mu)
  x = x(:);
  z = (x - mu) ./ alpha;
  F = exp(-exp(-z));
end

function q = gumbel_inv(p, alpha, mu)
  p = p(:);
  q = mu - alpha .* log(-log(p));
end

function params = fit_model_bootstrap(datos_boot)
  media_b = mean(datos_boot);
  desv_b = std(datos_boot);

  alpha_b = (sqrt(6) / pi) * desv_b;
  mu_b = media_b - 0.5772156649 * alpha_b;

  if isnan(alpha_b) || isnan(mu_b) || isinf(alpha_b) || isinf(mu_b) || alpha_b <= 0
      params = [NaN NaN];
  else
      params = [alpha_b, mu_b];
  end
end

function q = quantile_model_bootstrap(P, params)
  alpha_b = params(1);
  mu_b = params(2);
  q = gumbel_inv(P, alpha_b, mu_b);
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
    error('No se pudo leer la hoja "%s". Verifica que exista.', nombre_hoja);
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
    error('No hay suficientes datos vˆhlidos en la hoja "%s".', nombre_hoja);
end

fprintf('\nDiagnˆustico de lectura:\n');
fprintf('Primeros 10 mˆhximos anuales:\n');
disp(datos(1:min(10,end))');

media = mean(datos);
desvstd = std(datos);

alpha = (sqrt(6) / pi) * desvstd;
mu = media - 0.5772156649 * alpha;

fprintf('\nTributario analizado: %s\n', nombre_hoja);
fprintf('Nˆymero de datos vˆhlidos: %d\n', N);
fprintf('Media: %.4f\n', media);
fprintf('Desviaciˆun estˆhndar: %.4f\n', desvstd);
fprintf('Parˆhmetro de escala alpha: %.6f\n', alpha);
fprintf('Parˆhmetro de ubicaciˆun mu: %.6f\n\n', mu);

datos_desc = sort(datos, 'descend');
fprintf('  m  |  T_empirico  |  Dato\n');
fprintf('-----------------------------\n');
for m = 1:N
    T_empirico = (N + 1) / m;
    P_actual = datos_desc(m);
    fprintf(' %3d |   %8.2f   | %10.4f\n', m, T_empirico, P_actual);
end

estimaciones_base = NaN(1, length(Tr));

fprintf('\nEstimaciones con distribuciˆun Gumbel EV1:\n');
for i = 1:length(Tr)
    Tret = Tr(i);
    P = (Tret - 1) / Tret;
    estimacion = gumbel_inv(P, alpha, mu);
    estimaciones_base(i) = estimacion;
    fprintf('Tr: %3d | Prob: %6.3f | Estimaciˆun: %10.4f\n', Tret, P, estimacion);
end

nombre_archivo_estructural = ['incertidumbre_estructural_' nombre_hoja '.xlsx'];
guardar_resultado_estructural(nombre_archivo_estructural, nombre_modelo, Tr, estimaciones_base);

x = linspace(min(datos) * 0.8, max(datos) * 1.2, 1000);
x = x(:);

pdf_gumbel = gumbel_pdf(x, alpha, mu);
F_teo = gumbel_cdf(x, alpha, mu);
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

pdf_escalada = pdf_gumbel * N * bin_width;
plot(x, pdf_escalada, 'r', 'LineWidth', 2);

title(['Ajuste Gumbel EV1 - ', nombre_hoja]);
xlabel('Dato');
ylabel('Frecuencia');
legend('Histograma', 'Gumbel ajustada');
grid on;

figure;
plot(datos(:), F_emp(:), 'bo', 'MarkerSize', 5);
hold on;
plot(x(:), F_teo(:), 'r', 'LineWidth', 2);

title(['CDF Empˆqrica vs Gumbel EV1 - ', nombre_hoja]);
xlabel('Dato');
ylabel('Probabilidad acumulada');
legend('Empˆqrica', 'Gumbel EV1');
grid on;

figure;
p = ((1:N)' - 0.5) / N;
p = p(:);

q_teo = gumbel_inv(p, alpha, mu);
q_teo = q_teo(:);
datos = datos(:);

plot(q_teo, datos, 'bo');
hold on;

min_ref = min(min(q_teo), min(datos));
max_ref = max(max(q_teo), max(datos));
plot([min_ref max_ref], [min_ref max_ref], 'r--');

title(['QQ-Plot Gumbel EV1 - ', nombre_hoja]);
xlabel('Cuantiles teˆuricos');
ylabel('Datos observados');
grid on;

figure;
F_teo_datos = gumbel_cdf(datos, alpha, mu);
F_teo_datos = F_teo_datos(:);

plot(F_teo_datos, F_emp, 'bo');
hold on;
plot([0 1], [0 1], 'r--');

title(['PP-Plot Gumbel EV1 - ', nombre_hoja]);
xlabel('CDF teˆurica');
ylabel('CDF empˆqrica');
grid on;

fprintf('INCERTIDUMBRE MUESTRAL POR BOOTSTRAP\n');


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

fprintf('Modelo: %s\n', nombre_modelo);
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

    q_base = gumbel_inv(P, alpha, mu);

    q_alpha_m = gumbel_inv(P, alpha*0.95, mu);
    q_alpha_p = gumbel_inv(P, alpha*1.05, mu);

    q_mu_m = gumbel_inv(P, alpha, mu*0.95);
    q_mu_p = gumbel_inv(P, alpha, mu*1.05);

    fprintf('\nTr = %d\n', Tret);
    fprintf('Base         : %10.4f\n', q_base);
    fprintf('alpha -5%%   : %10.4f | alpha +5%%   : %10.4f\n', q_alpha_m, q_alpha_p);
    fprintf('mu    -5%%   : %10.4f | mu    +5%%   : %10.4f\n', q_mu_m, q_mu_p);
end


fprintf('DETECCIˆ_N DE INESTABILIDAD DEL MODELO\n');


flag_inestable = 0;

if alpha <= 1e-6
    fprintf('Advertencia: alpha degenerado o cercano a cero.\n');
    flag_inestable = 1;
end

q100 = gumbel_inv((100-1)/100, alpha, mu);

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
