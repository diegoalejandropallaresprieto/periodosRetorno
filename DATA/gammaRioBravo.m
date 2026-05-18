1;
clc;
clear;
close all;1;
clc;
clear;
close all;

pkg load io;
pkg load statistics;

fprintf('\n>>> INICIANDO SCRIPT GAMMA <<<\n');

nombre_modelo = 'Gamma';
filename = 'Entregas Historicas.xlsx';
Tr = [2, 5, 10, 25, 50, 100];


function x = invgam(P, k, theta)
  if P <= 0 || P >= 1 || k <= 0 || theta <= 0
    x = NaN;
    return;
  end

  tol = 1e-5;
  x_inf = 0;
  x_sup = max(theta * k, 1);

  while gammainc(x_sup/theta, k) < P
    x_sup = x_sup * 2;
    if x_sup > 1e10
      break;
    end
  end

  while (x_sup - x_inf) > tol
    mid = (x_inf + x_sup) / 2;
    if gammainc(mid/theta, k) < P
      x_inf = mid;
    else
      x_sup = mid;
    end
  end

  x = (x_inf + x_sup) / 2;
end

function params = fit_model_bootstrap(datos_boot)
  media_b = mean(datos_boot);
  var_b = var(datos_boot);

  if media_b <= 0 || var_b <= 0
    params = [NaN NaN];
    return;
  end

  k_b = (media_b^2) / var_b;
  theta_b = var_b / media_b;

  params = [k_b, theta_b];
end

function pval = percentile_manual(x, p)
  x = sort(x(:));
  n = length(x);

  pos = 1 + (n - 1) * (p / 100);
  lo = floor(pos);
  hi = ceil(pos);

  if lo == hi
      pval = x(lo);
  else
      pval = x(lo) + (pos - lo) * (x(hi) - x(lo));
  end
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
for k = 1:length(tributarios)
    fprintf('%d. %s\n', k, tributarios{k});
end

idx = input('Selecciona el nˆymero del tributario: ');
nombre_hoja = tributarios{idx};

[~, ~, raw] = xlsread(filename, nombre_hoja);

bloque = raw(2:end, 2:end);
[nr, nc] = size(bloque);

matriz = NaN(nr, nc);

for i = 1:nr
    for j = 1:nc
        if isnumeric(bloque{i,j})
            matriz(i,j) = bloque{i,j};
        end
    end
end

datos = max(matriz, [], 1);
datos = datos(:);
datos = datos(~isnan(datos));
datos = sort(datos);

N = length(datos);

fprintf('\n>>> DATOS CARGADOS: %d\n', N);

media = mean(datos);
varianza = var(datos);

k = (media^2) / varianza;
theta = varianza / media;

fprintf('\nPARAMETROS GAMMA:\n');
fprintf('k = %.4f\n', k);
fprintf('theta = %.4f\n', theta);

fprintf('\nEstimaciones base:\n');

for i = 1:length(Tr)
    P = (Tr(i)-1)/Tr(i);
    x = invgam(P, k, theta);
    fprintf('Tr=%d -> %.4f\n', Tr(i), x);
end

n_boot = 200;
boot_est = NaN(n_boot, length(Tr));

for b = 1:n_boot
    idx_boot = randi(N, N, 1);
    datos_boot = datos(idx_boot);

    params = fit_model_bootstrap(datos_boot);

    for t = 1:length(Tr)
        P = (Tr(t)-1)/Tr(t);
        boot_est(b,t) = invgam(P, params(1), params(2));
    end
end

fprintf('RESULTADOS BOOTSTRAP\n');

for t = 1:length(Tr)
    vals = boot_est(:,t);
    vals = vals(~isnan(vals));

    media_b = mean(vals);
    std_b = std(vals);
    p025 = percentile_manual(vals,2.5);
    p975 = percentile_manual(vals,97.5);

    fprintf('Tr=%d | Media=%.2f | Std=%.2f | IC=[%.2f , %.2f]\n',
        Tr(t), media_b, std_b, p025, p975);
end


figure;
boxplot(boot_est);
title('Bootstrap Gamma');

fprintf('\n>>> SENSIBILIDAD PARAMETRICA <<<\n');

for T = [50 100]
    P = (T-1)/T;

    base = invgam(P,k,theta);
    k_low = invgam(P,k*0.95,theta);
    k_high = invgam(P,k*1.05,theta);

    fprintf('\nTr=%d\n',T);
    fprintf('Base=%.2f\n',base);
    fprintf('k-5%%=%.2f | k+5%%=%.2f\n',k_low,k_high);
end

fprintf('\n>>> ANALISIS DE INESTABILIDAD <<<\n');

cv = std(boot_est(:,end))/mean(boot_est(:,end));
fprintf('CV Tr=100 = %.4f\n',cv);

if cv > 0.3
    fprintf('?? MODELO INESTABLE\n');
else
    fprintf('Modelo estable\n');
end
