1;
clc;
clear;
close all;

pkg load io;

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
for k = 1:length(tributarios)
    fprintf('%d. %s\n', k, tributarios{k});
end

idx = input('Selecciona el nˆymero del tributario a analizar: ');
nombre_hoja = tributarios{idx};

[num, txt, raw] = xlsread(filename, nombre_hoja);

if isempty(raw)
    error('No se pudo leer la hoja "%s". Verifica que exista en el archivo.', nombre_hoja);
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

if N < 2
    error('No hay suficientes datos vˆhlidos en la hoja "%s".', nombre_hoja);
end

fprintf('\nDiagnˆustico de lectura:\n');
fprintf('Primeros 10 mˆhximos anuales:\n');
disp(datos(1:min(10,end))');

xm = min(datos);
suma = sum(log(datos ./ xm));
alpha = N / suma;

fprintf('\nTributario analizado: %s\n', nombre_hoja);
fprintf('Nˆymero de datos vˆhlidos: %d\n', N);
fprintf('Parˆhmetro de escala xm: %.4f\n', xm);
fprintf('Parˆhmetro de forma alpha: %.4f\n', alpha);

Tr = [2, 5, 10, 25, 50, 100];

fprintf('\nEstimaciones por periodo de retorno:\n');
for i = 1:length(Tr)
    Tret = Tr(i);
    P = (Tret - 1) / Tret;
    estimacion = xm * (Tret^(1/alpha));
    fprintf('Tr = %3d | Prob = %6.3f | Estimaciˆun = %10.4f\n', Tret, P, estimacion);
end

T_usuario = input('\nDime un periodo de retorno a evaluar: ');

if isempty(T_usuario) || T_usuario <= 1
    fprintf('Periodo de retorno no vˆhlido. Debe ser mayor que 1.\n');
else
    x_usuario = xm * (T_usuario^(1/alpha));
    fprintf('La estimaciˆun para Tr = %.2f es: %.4f\n', T_usuario, x_usuario);
end

x = linspace(xm, max(datos) * 1.2, 1000);
x = x(:);

pdf_pareto = (alpha * xm^alpha) ./ (x.^(alpha + 1));
F_teo = 1 - (xm ./ x).^alpha;
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

pdf_escalada = pdf_pareto * N * bin_width;
plot(x, pdf_escalada, 'r', 'LineWidth', 2);

title(['Ajuste Pareto - ', nombre_hoja]);
xlabel('Dato');
ylabel('Frecuencia');
legend('Histograma', 'Pareto ajustada');
grid on;

figure;
plot(datos(:), F_emp(:), 'bo', 'MarkerSize', 5);
hold on;
plot(x(:), F_teo(:), 'r', 'LineWidth', 2);

title(['CDF Empˆqrica vs Pareto - ', nombre_hoja]);
xlabel('Dato');
ylabel('Probabilidad acumulada');
legend('Empˆqrica', 'Pareto');
grid on;

figure;
p = ((1:N)' - 0.5) / N;
p = p(:);

q_teo = xm ./ ((1 - p).^(1/alpha));
q_teo = q_teo(:);
datos = datos(:);

plot(q_teo, datos, 'bo');
hold on;

min_ref = min(min(q_teo), min(datos));
max_ref = max(max(q_teo), max(datos));
plot([min_ref max_ref], [min_ref max_ref], 'r--');

title(['QQ-Plot Pareto - ', nombre_hoja]);
xlabel('Cuantiles teˆuricos');
ylabel('Datos observados');
grid on;

figure;
F_teo_datos = 1 - (xm ./ datos).^alpha;
F_teo_datos = F_teo_datos(:);
F_emp = F_emp(:);

plot(F_teo_datos, F_emp, 'bo');
hold on;
plot([0 1], [0 1], 'r--');

title(['PP-Plot Pareto - ', nombre_hoja]);
xlabel('CDF teˆurica');
ylabel('CDF empˆqrica');
grid on;
