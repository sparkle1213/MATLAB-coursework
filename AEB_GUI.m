function varargout = AEB_GUI(mode)
%AEB_GUI  手搓版 AEB 模型单文件可视化仿真界面。
%   AEB_GUI()            打开 GUI（默认）。
%   AEB_GUI('ui')        打开 GUI。
%   AEB_GUI('selftest')  无界面自检：默认参数仿真、打印指标、保存 4 张图。
%
%   目标模型：AEB_v1_wzq.slx（与本文件同目录）。
%   本程序只通过 set_param 修改内存中的模型，运行后 close_system(mdl,0)，
%   从不 save_system，因此不会改动 SLX 文件。
%
%   输出图片保存到本文件同目录下的 picture/：
%       01_gap.png, 02_speed.png, 03_decel.png, 04_ttc_state.png

    if nargin < 1 || isempty(mode)
        mode = 'ui';
    end
    if isstring(mode)
        mode = char(mode);
    end
    if ~ischar(mode)
        error('AEB_GUI:BadMode', '输入模式必须是字符向量或字符串。');
    end
    mode = lower(strtrim(mode));

    switch mode
        case 'ui'
            fig = build_ui();
            if nargout > 0
                varargout{1} = fig;
            end
        case 'selftest'
            run_selftest();
            if nargout > 0
                varargout{1} = [];
            end
        otherwise
            error('AEB_GUI:BadMode', ...
                '未知模式 "%s"，可用模式为 "ui" 或 "selftest"。', mode);
    end
end

% =====================================================================
% GUI 构建
% =====================================================================
function fig = build_ui()
    rootDir = gui_root();
    specs = param_specs();
    fname = ui_font_name();

    fig = uifigure('Name', 'AEB 可视化仿真 — AEB_v1_wzq', ...
        'Position', [60 40 1400 860], ...
        'Color', [0.95 0.96 0.98], ...
        'Resize', 'off');

    main = uigridlayout(fig, [1 2]);
    main.ColumnWidth = {410, '1x'};
    main.RowHeight = {'1x'};
    main.Padding = [8 8 8 8];
    main.ColumnSpacing = 8;

    % ---------------- 左侧：参数区 ----------------
    left = uipanel(main, 'Title', '参数设置', ...
        'FontName', fname, 'FontWeight', 'bold');
    left.Layout.Row = 1;
    left.Layout.Column = 1;

    lg = uigridlayout(left, [2 1]);
    lg.RowHeight = {'1x', 86};
    lg.Padding = [6 6 6 6];
    lg.RowSpacing = 6;

    scroll = uipanel(lg, 'BorderType', 'none', 'Scrollable', 'on');
    scroll.Layout.Row = 1;
    scroll.Layout.Column = 1;

    ctrl = uigridlayout(lg, [2 2]);
    ctrl.Layout.Row = 2;
    ctrl.Layout.Column = 1;
    ctrl.RowHeight = {30, 44};
    ctrl.ColumnWidth = {'1x', '1x'};
    ctrl.Padding = [0 0 0 0];
    ctrl.RowSpacing = 4;
    ctrl.ColumnSpacing = 6;

    btnReset = uibutton(ctrl, 'push', 'Text', '恢复默认值', ...
        'FontName', fname, 'FontSize', 12);
    btnReset.Layout.Row = 1;
    btnReset.Layout.Column = 1;

    btnRun = uibutton(ctrl, 'push', 'Text', '开始仿真', ...
        'FontName', fname, 'FontSize', 13, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.12 0.45 0.80], 'FontColor', [1 1 1]);
    btnRun.Layout.Row = 1;
    btnRun.Layout.Column = 2;

    statusLbl = uilabel(ctrl, 'Text', '就绪：修改参数后点击“开始仿真”', ...
        'FontName', fname, 'FontSize', 11, 'FontColor', [0.25 0.25 0.25], ...
        'WordWrap', 'on');
    statusLbl.Layout.Row = 2;
    statusLbl.Layout.Column = [1 2];

    % 参数按分组逐行排布（滚动面板内使用绝对坐标）
    rowH = 28;
    headerH = 26;
    groupGap = 8;
    topPad = 8;
    bottomPad = 8;
    groupOrder = {'场景', '风险与决策', 'PID', '执行机构'};
    contentH = topPad + bottomPad + numel(groupOrder) * headerH ...
        + numel(specs) * rowH + numel(groupOrder) * groupGap;

    y = contentH - topPad;
    currentGroup = '';
    edits = cell(numel(specs), 1);
    for k = 1:numel(specs)
        s = specs(k);
        if ~strcmp(s.group, currentGroup)
            currentGroup = s.group;
            y = y - headerH;
            uilabel(scroll, 'Text', currentGroup, ...
                'Position', [6 y 380 headerH - 2], ...
                'FontName', fname, 'FontSize', 12, 'FontWeight', 'bold', ...
                'BackgroundColor', [0.87 0.92 0.98], ...
                'FontColor', [0.05 0.25 0.55]);
            y = y - groupGap;
        end
        y = y - rowH;

        uilabel(scroll, 'Text', s.label, ...
            'Position', [6 y + 2 142 22], ...
            'FontName', fname, 'FontSize', 11, ...
            'HorizontalAlignment', 'right', 'FontColor', [0.15 0.15 0.15]);

        tooltip = sprintf('%s [%s]；模型块：%s', s.label, s.unit, s.block);
        if strcmp(s.type, 'text')
            ed = uieditfield(scroll, 'text', 'Value', 'Inf', ...
                'Position', [152 y + 2 100 22], ...
                'FontName', fname, 'FontSize', 11, 'Tooltip', tooltip);
        else
            ed = uieditfield(scroll, 'numeric', 'Value', s.default, ...
                'Position', [152 y + 2 100 22], ...
                'FontName', fname, 'FontSize', 11, ...
                'ValueDisplayFormat', '%.6g', 'Tooltip', tooltip);
        end
        if s.readonly
            ed.Editable = 'off';
            ed.BackgroundColor = [0.93 0.93 0.93];
        end
        edits{k} = ed;

        uilabel(scroll, 'Text', s.unit, ...
            'Position', [258 y + 4 130 18], ...
            'FontName', fname, 'FontSize', 10, 'FontColor', [0.40 0.40 0.40]);
    end

    % ---------------- 右侧：指标 + 曲线 ----------------
    right = uigridlayout(main, [2 1]);
    right.Layout.Row = 1;
    right.Layout.Column = 2;
    right.RowHeight = {200, '1x'};
    right.RowSpacing = 8;
    right.Padding = [0 0 0 0];

    mp = uipanel(right, 'Title', '输出指标', ...
        'FontName', fname, 'FontWeight', 'bold');
    mp.Layout.Row = 1;

    mg = uigridlayout(mp, [3 3]);
    mg.RowHeight = {'1x', '1x', '1x'};
    mg.ColumnWidth = {'1x', '1x', '1x'};
    mg.Padding = [6 6 6 6];
    mg.RowSpacing = 6;
    mg.ColumnSpacing = 6;

    metricTitles = { ...
        '最小车距 d_min [m]', ...
        '末车距 d_final [m]', ...
        '峰值减速度 a_peak [m/s²]', ...
        '末速度 v_final [m/s]', ...
        '停稳时刻 t_stop [s]', ...
        '部分制动时刻 t_pba [s]', ...
        '是否碰撞', ...
        '碰撞速度 impact [m/s]', ...
        '状态序列 0/1/2/3'};
    metricLabels = cell(1, 9);
    for k = 1:9
        tile = uipanel(mg, 'BorderType', 'line', ...
            'BackgroundColor', [1 1 1], 'FontName', fname);
        tg = uigridlayout(tile, [2 1]);
        tg.RowHeight = {18, '1x'};
        tg.Padding = [8 3 8 3];
        tg.RowSpacing = 0;
        uilabel(tg, 'Text', metricTitles{k}, ...
            'FontName', fname, 'FontSize', 10, 'FontColor', [0.35 0.35 0.35]);
        metricLabels{k} = uilabel(tg, 'Text', '--', ...
            'FontName', fname, 'FontSize', 16, 'FontWeight', 'bold', ...
            'FontColor', [0.05 0.25 0.55]);
    end

    pp = uipanel(right, 'Title', '曲线（运行后自动保存到 picture/）', ...
        'FontName', fname, 'FontWeight', 'bold');
    pp.Layout.Row = 2;

    pg = uigridlayout(pp, [2 2]);
    pg.RowHeight = {'1x', '1x'};
    pg.ColumnWidth = {'1x', '1x'};
    pg.Padding = [6 6 6 6];
    pg.RowSpacing = 6;
    pg.ColumnSpacing = 6;

    axs = cell(1, 4);
    for k = 1:4
        axs{k} = uiaxes(pg);
        axs{k}.Layout.Row = 1 + floor((k - 1) / 2);
        axs{k}.Layout.Column = 1 + mod(k - 1, 2);
    end
    init_axes(axs);

    % ---------------- 应用状态与回调 ----------------
    app = struct();
    app.root = rootDir;
    app.specs = specs;
    app.edits = edits;
    app.btnRun = btnRun;
    app.btnReset = btnReset;
    app.status = statusLbl;
    app.axes = axs;
    app.metricLabels = metricLabels;
    fig.UserData = app;

    btnRun.ButtonPushedFcn = @(~, ~) on_run(fig);
    btnReset.ButtonPushedFcn = @(~, ~) on_reset(fig);

    drawnow;
end

function init_axes(axs)
    fname = ui_font_name();
    titles = {'车距', '速度', '减速度', 'TTC 与状态'};
    ylabels = {'净车距 d [m]', '速度 [m/s]', '减速度幅值 [m/s²]', 'TTC [s] / 状态'};
    for k = 1:4
        ax = axs{k};
        cla(ax, 'reset');
        style_axes(ax);
        title(ax, titles{k});
        xlabel(ax, 't [s]');
        ylabel(ax, ylabels{k});
        text(ax, 0.5, 0.5, '运行仿真后显示曲线', ...
            'Units', 'normalized', 'HorizontalAlignment', 'center', ...
            'FontName', fname, 'FontSize', 12, 'Color', [0.55 0.55 0.55]);
    end
end

% =====================================================================
% 回调
% =====================================================================
function on_run(fig)
    app = fig.UserData;
    if ~strcmp(app.btnRun.Enable, 'on')
        return;
    end
    app.btnRun.Enable = 'off';
    app.btnReset.Enable = 'off';
    app.status.Text = '仿真中…（首次运行编译模型可能需要几十秒）';
    fig.Pointer = 'watch';
    drawnow;

    uiCleaner = onCleanup(@() restore_ui(fig));

    try
        params = read_params(app);
        validate_params(params);
        [metrics, logs] = simulate_model(params);
        draw_all(app.axes, logs);

        picDir = fullfile(gui_root(), 'picture');
        save_plots(logs, picDir);
        update_metrics(app, metrics);

        if metrics.collision_inferred
            app.status.Text = sprintf( ...
                '仿真完成：碰撞=是（日志缺终止采样，按 d≤0 判定，impact 为估算）');
        elseif metrics.collision_mismatch
            app.status.Text = sprintf( ...
                '仿真完成（警告：碰撞日志为真，但 d_min = %.3f m > 0）', ...
                metrics.d_min);
        else
            app.status.Text = sprintf('仿真完成：d_min = %.3f m，碰撞：%s', ...
                metrics.d_min, yes_no(metrics.collision));
        end
    catch err
        app.status.Text = '仿真失败，请查看提示';
        fprintf(2, '[AEB_GUI] %s\n', err.message);
        uialert(fig, err.message, 'AEB 仿真失败', 'Icon', 'error');
    end
end

function on_reset(fig)
    app = fig.UserData;
    for k = 1:numel(app.specs)
        if ~app.specs(k).readonly
            set_edit_value(app.edits{k}, app.specs(k), app.specs(k).default);
        end
    end
    app.status.Text = '已恢复模型默认参数（尚未重新仿真）';
end

function restore_ui(fig)
    try
        if isvalid(fig)
            app = fig.UserData;
            app.btnRun.Enable = 'on';
            app.btnReset.Enable = 'on';
            fig.Pointer = 'arrow';
            drawnow;
        end
    catch
        % 窗口已关闭时忽略。
    end
end

% =====================================================================
% 参数读取、校验与写入
% =====================================================================
function params = read_params(app)
    params = struct();
    for k = 1:numel(app.specs)
        s = app.specs(k);
        ed = app.edits{k};
        if strcmp(s.type, 'text')
            txt = strtrim(ed.Value);
            if isempty(txt)
                v = NaN;
            elseif any(strcmpi(txt, {'inf', '+inf', 'infinity', '∞'}))
                v = Inf;
            else
                v = str2double(txt);
            end
        else
            v = ed.Value;
            if isempty(v)
                v = NaN;
            end
        end
        params.(s.key) = double(v);
    end
end

function validate_params(p)
    specs = param_specs();

    for k = 1:numel(specs)
        s = specs(k);
        v = p.(s.key);
        if ~isnumeric(v) || ~isscalar(v) || ~isreal(v)
            fail_param(s, '必须是实数标量。');
        end
        if strcmp(s.key, 't_brake')
            if ~(isinf(v) && v > 0) && ~(isfinite(v) && v >= s.min && v <= s.max)
                fail_param(s, sprintf( ...
                    '必须为 Inf（不变速）或 [%g, %g] 范围内的秒数。', s.min, s.max));
            end
        else
            if ~isfinite(v)
                fail_param(s, '必须是有限数值。');
            end
            if v < s.min || v > s.max
                fail_param(s, sprintf('必须在 [%g, %g] %s 范围内。', ...
                    s.min, s.max, s.unit));
            end
        end
    end

    if ~(p.TTC_warn > p.TTC_brake)
        fail_param(spec_by_key(specs, 'TTC_warn'), '必须大于“制动进入 TTC”。');
    end
    if ~(p.TTC_warn > p.TTC_pba)
        fail_param(spec_by_key(specs, 'TTC_pba'), '必须小于“预警 TTC 阈值”。');
    end
    if ~(p.TTC_pba > p.TTC_brake)
        fail_param(spec_by_key(specs, 'TTC_pba'), '必须大于“制动进入 TTC”。');
    end
    if ~(p.TTC_brake_off >= p.TTC_brake)
        fail_param(spec_by_key(specs, 'TTC_brake_off'), ...
            '必须大于或等于“制动进入 TTC”。');
    end
    if abs(p.Ts - 0.01) > 1e-12
        fail_param(spec_by_key(specs, 'Ts'), ...
            '固定为 0.01 s，以匹配 PID、决策和执行机构的离散周期。');
    end
end

function fail_param(s, msg)
    error('AEB_GUI:InvalidParam', '参数“%s”%s', s.label, msg);
end

function s = spec_by_key(specs, key)
    s = specs(strcmp({specs.key}, key));
    if isempty(s)
        error('AEB_GUI:BadSpec', '内部参数表缺少键：%s', key);
    end
    s = s(1);
end

function set_edit_value(ed, s, v)
    if strcmp(s.type, 'text')
        if isinf(v)
            ed.Value = 'Inf';
        else
            ed.Value = sprintf('%g', v);
        end
    else
        ed.Value = v;
    end
end

function apply_params(p)
    mdl = 'AEB_v1_wzq';
    if ~bdIsLoaded(mdl)
        error('AEB_GUI:ModelNotLoaded', '模型 %s 尚未加载。', mdl);
    end

    % 1) 场景参数向量 [gap0, v_target0, a_target, t_brake]
    pathScenario = [mdl '/传感器/场景参数向量 ScenarioParams [初始距离，初速度，加速度，刹车时间]'];
    v = get_numeric_vector(pathScenario, 'ScenarioParams');
    if numel(v) ~= 4
        error('AEB_GUI:ModelParse', 'ScenarioParams 应为 4 个元素，实际为 %d 个。', numel(v));
    end
    v(1) = p.gap0;
    v(2) = p.v_target0_kmh / 3.6;
    v(3) = p.a_target;
    v(4) = p.t_brake;
    set_param(pathScenario, 'Value', vec2str(v));

    % 2) 自车初速（积分器初值）
    set_param([mdl '/自车状态 Vehicle/Integrator_v'], ...
        'InitialCondition', fmt_num(p.v_ego0_kmh / 3.6));

    % 3) 风险与决策标量
    set_param([mdl '/风险计算/路面附着系数mu'], 'Value', fmt_num(p.mu));
    set_param([mdl '/风险计算/目标制动减速度 a_brake_g'], 'Value', fmt_num(p.a_brake_g));
    set_param([mdl '/决策/部分制动强度 a_pba_g'], 'Value', fmt_num(p.a_pba_g));
    set_param([mdl '/风险计算/停车余量 d_margin'], 'Value', fmt_num(p.d_margin));
    set_param([mdl '/决策/预警阈值 TTC_warn'], 'Value', fmt_num(p.TTC_warn));
    set_param([mdl '/决策/部分制动阈值 TTC_pba'], 'Value', fmt_num(p.TTC_pba));
    set_param([mdl '/决策/制动进入阈值 TTC_brake'], 'Value', fmt_num(p.TTC_brake));
    set_param([mdl '/决策/制动阈值 TTC_brake_off'], 'Value', fmt_num(p.TTC_brake_off));
    set_param([mdl '/决策/ 停稳判定阈值 v_stop'], 'Value', fmt_num(p.v_stop));

    % 4) PID 参数向量 [Kp, Ki, Kd, Ts]
    pathPid = [mdl '/PID/内部参数 PidParams [Kp, Ki, Kd, Ts]'];
    vp = get_numeric_vector(pathPid, 'PidParams');
    if numel(vp) ~= 4
        error('AEB_GUI:ModelParse', 'PidParams 应为 4 个元素，实际为 %d 个。', numel(vp));
    end
    vp(1) = p.Kp;
    vp(2) = p.Ki;
    vp(3) = p.Kd;
    vp(4) = p.Ts;
    set_param(pathPid, 'Value', vec2str(vp));

    % 5) 执行机构 ActParams（保持原有 20 元素与列向量方向）
    pathAct = [mdl '/执行机构 主缸助力电机液压/ActParams'];
    va = get_numeric_vector(pathAct, 'ActParams');
    if numel(va) ~= 20
        error('AEB_GUI:ModelParse', 'ActParams 应为 20 个元素，实际为 %d 个。', numel(va));
    end
    va(1) = p.k_dec;
    va(4) = p.tau_fill;
    va(5) = p.tau_rel;
    set_param(pathAct, 'Value', vec2str(va));
end

function v = get_numeric_vector(path, label)
    s = get_param(path, 'Value');
    v = str2num(s); %#ok<ST2NM>
    if isempty(v) || ~isnumeric(v) || ~isreal(v)
        error('AEB_GUI:ModelParse', ...
            '无法解析模型参数 %s 的常数向量：%s', label, s);
    end
end

function s = vec2str(v)
    if isrow(v)
        sep = ' ';
    else
        sep = ';';
    end
    parts = arrayfun(@(x) fmt_num(x), v(:).', 'UniformOutput', false);
    s = ['[' strjoin(parts, sep) ']'];
end

function s = fmt_num(x)
    if isnan(x)
        s = 'NaN';
    elseif isinf(x)
        if x > 0
            s = 'Inf';
        else
            s = '-Inf';
        end
    else
        s = num2str(x, 17);
    end
end

% =====================================================================
% 仿真与日志读取
% =====================================================================
function [metrics, logs] = simulate_model(params)
    rootDir = gui_root();
    mdl = 'AEB_v1_wzq';
    modelFile = fullfile(rootDir, [mdl '.slx']);
    if ~isfile(modelFile)
        error('AEB_GUI:ModelMissing', '找不到模型文件：%s', modelFile);
    end

    % 把编译缓存重定向到系统临时目录，避免在交付目录生成 slprj。
    cacheDir = fullfile(tempdir, 'AEB_GUI_sim_cache');
    cacheCleaner = push_sim_cache(cacheDir); %#ok<NASGU>

    wasLoaded = bdIsLoaded(mdl);
    if wasLoaded
        % MATLAB 里可能还开着旧版模型（例如没有 PBA 块）。这时 set_param
        % 会报“Simulink 对象名称无效”。检测到旧版就先关闭（不保存）再重载。
        neededBlocks = { ...
            [mdl '/决策/部分制动强度 a_pba_g'], ...
            [mdl '/决策/部分制动阈值 TTC_pba']};
        stale = false;
        for k = 1:numel(neededBlocks)
            if getSimulinkBlockHandle(neededBlocks{k}) < 0
                stale = true;
                break;
            end
        end
        if stale
            close_system(mdl, 0);
            wasLoaded = false;
        end
    end
    if ~wasLoaded
        load_system(modelFile);
    end
    modelCleaner = onCleanup(@() close_model_if_needed(mdl, wasLoaded));

    apply_params(params);
    simOut = sim(mdl, 'ReturnWorkspaceOutputs', 'on');
    logs = extract_logs(simOut);
    metrics = compute_metrics(logs, params);
end

function cleaner = push_sim_cache(cacheDir)
    try
        oldCfg = Simulink.fileGenControl('getConfig');
        Simulink.fileGenControl('set', ...
            'CacheFolder', cacheDir, ...
            'CodeGenFolder', cacheDir, ...
            'createDir', true, ...
            'keepPreviousPath', true);
        cleaner = onCleanup(@() restore_sim_cache(oldCfg));
    catch
        cleaner = [];
    end
end

function restore_sim_cache(oldCfg)
    try
        Simulink.fileGenControl('setConfig', 'config', oldCfg);
    catch
        % 恢复失败不影响仿真结果。
    end
end

function close_model_if_needed(mdl, wasLoaded)
    if wasLoaded
        return;
    end
    try
        if bdIsLoaded(mdl)
            close_system(mdl, 0);   % 0 = 不保存
        end
    catch
    end
end

function logs = extract_logs(simOut)
    names = { ...
        'log_d', 'log_v_ego', 'log_v_target', 'log_TTC', 'log_state', ...
        'log_a_cmd', 'log_a_act', 'log_p_wc', 'log_p_wc1'};

    ts = cell(1, numel(names));
    missing = {};
    for k = 1:numel(names)
        ts{k} = get_ts(simOut, names{k});
        if isempty(ts{k})
            missing{end + 1} = names{k}; %#ok<AGROW>
        end
    end
    if ~isempty(missing)
        error('AEB_GUI:MissingLogs', ...
            '仿真输出缺少变量：%s（请检查模型的 9 个 To Workspace 块）。', ...
            strjoin(missing, ', '));
    end

    logs = struct();
    [logs.t_d, logs.d] = ts_tv(ts{1}, names{1});
    [logs.t_v, logs.v_ego] = ts_tv(ts{2}, names{2});
    [logs.t_vt, logs.v_target] = ts_tv(ts{3}, names{3});
    [logs.t_ttc, logs.TTC] = ts_tv(ts{4}, names{4});
    [logs.t_state, logs.state] = ts_tv(ts{5}, names{5});
    [logs.t_acmd, logs.a_cmd] = ts_tv(ts{6}, names{6});
    [logs.t_aact, logs.a_act] = ts_tv(ts{7}, names{7});
    [logs.t_pwc, logs.p_wc] = ts_tv(ts{8}, names{8});
    % 重要：块名 log_collision 的实际 VariableName 是 log_p_wc1。
    [logs.t_collision, logs.collision] = ts_tv(ts{9}, names{9});
end

function ts = get_ts(simOut, name)
    ts = [];
    try
        v = simOut.get(name);
    catch
        return;
    end
    if isa(v, 'timeseries') && ~isempty(v.Time) && ~isempty(v.Data)
        ts = v;
    end
end

function [t, v] = ts_tv(ts, name)
    t = double(ts.Time(:));
    v = double(ts.Data(:));
    if isempty(t) || isempty(v) || numel(t) ~= numel(v)
        error('AEB_GUI:BadLog', ...
            '变量 %s 的时间/数据长度不一致（%d vs %d）。', ...
            name, numel(t), numel(v));
    end
end

% =====================================================================
% 指标计算
% =====================================================================
function m = compute_metrics(logs, params)
    if all(~isfinite(logs.d))
        error('AEB_GUI:BadLog', 'log_d 中没有有效车距数据。');
    end

    [m.d_min, idx] = min(logs.d);
    m.t_dmin = logs.t_d(idx);
    m.d_final = last_finite(logs.d);

    a = logs.a_act(isfinite(logs.a_act));
    if isempty(a)
        m.a_peak = NaN;
    else
        m.a_peak = max(a);
    end

    m.v_final = last_finite(logs.v_ego);

    idxStop = find(isfinite(logs.v_ego) & logs.v_ego <= params.v_stop, 1, 'first');
    if isempty(idxStop)
        m.t_stop = NaN;
    else
        m.t_stop = logs.t_v(idxStop);
    end

    c = logs.collision;
    m.collision_log = any(c > 0.5);
    m.gap_crossed = m.d_min <= 0;
    m.collision = m.collision_log || m.gap_crossed;
    m.collision_inferred = ~m.collision_log && m.gap_crossed;

    if m.collision_log
        ic = find(c > 0.5, 1, 'first');
        m.t_collision = logs.t_collision(ic);
        [~, j] = min(abs(logs.t_v - m.t_collision));
        m.impact = logs.v_ego(j);
        m.impact_time = m.t_collision;
        m.impact_source = 'log';
    elseif m.gap_crossed
        % Stop 块可能与 collision 的 To Workspace 同刻触发，导致最后一步
        % 的 collision=1 未写入日志。此时按 d<=0 判定碰撞，并用第一个
        % d<=0 采样时刻对齐 v_ego 估算 impact；若全部采样都为负，则用
        % 最小 d 样本。
        finiteD = isfinite(logs.d);
        if all(logs.d(finiteD) <= 0)
            [~, idx] = min(logs.d);
        else
            idx = find(logs.d <= 0, 1, 'first');
        end
        m.impact_time = logs.t_d(idx);
        [~, j] = min(abs(logs.t_v - m.impact_time));
        m.impact = logs.v_ego(j);
        m.impact_source = 'gap';
    else
        m.t_collision = NaN;
        m.impact = NaN;
        m.impact_time = NaN;
        m.impact_source = '';
    end

    st = logs.state(isfinite(logs.state));
    st = round(st(:));
    if isempty(st)
        m.state_seq = [];
    else
        keep = [true; diff(st) ~= 0];
        m.state_seq = st(keep).';
    end
    m.state_seq_str = format_state_seq(m.state_seq);

    % 第一次进入 PBA（state=2）的时刻。
    rawState = logs.state(:);
    idxPba = find(isfinite(rawState) & round(rawState) == 2, 1, 'first');
    if isempty(idxPba)
        m.t_pba = NaN;
    else
        m.t_pba = logs.t_state(idxPba);
    end

    % 交叉核验：碰撞日志与最小净距应一致。
    % 若 collision 日志未捕获终止采样（d_min<=0 但日志为 0），仍判定为
    % 碰撞，并在 GUI/自检中说明“按 d<=0 判定、impact 为估算口径”。
    m.collision_mismatch = (m.collision_log && m.d_min > 0.05) ...
        || m.collision_inferred;
end

function s = format_state_seq(seq)
    if isempty(seq)
        s = '[]';
    else
        parts = arrayfun(@(x) sprintf('%d', x), seq, 'UniformOutput', false);
        s = ['[' strjoin(parts, ' ') ']'];
    end
end

function v = last_finite(x)
    idx = find(isfinite(x), 1, 'last');
    if isempty(idx)
        v = NaN;
    else
        v = x(idx);
    end
end

% =====================================================================
% 绘图
% =====================================================================
function draw_all(axs, logs)
    draw_gap(axs{1}, logs);
    draw_speed(axs{2}, logs);
    draw_decel(axs{3}, logs);
    draw_ttc_state(axs{4}, logs);
end

function draw_gap(ax, logs)
    cla(ax, 'reset');
    plot(ax, logs.t_d, logs.d, 'LineWidth', 1.4, 'Color', [0 0.447 0.741]);
    style_axes(ax);
    title(ax, '车距');
    xlabel(ax, 't [s]');
    ylabel(ax, '净车距 d [m]');
    legend(ax, {'净车距 d'}, 'Location', 'best');
    xlim(ax, [0, max(logs.t_d)]);
end

function draw_speed(ax, logs)
    cla(ax, 'reset');
    h1 = plot(ax, logs.t_v, logs.v_ego, 'LineWidth', 1.4);
    hold(ax, 'on');
    h2 = plot(ax, logs.t_vt, logs.v_target, 'LineWidth', 1.4);
    hold(ax, 'off');
    style_axes(ax);
    title(ax, '自车与目标车速度');
    xlabel(ax, 't [s]');
    ylabel(ax, '速度 [m/s]');
    legend(ax, [h1 h2], {'自车 v_{ego}', '目标车 v_{target}'}, 'Location', 'best');
    xlim(ax, [0, max([logs.t_v; logs.t_vt])]);
end

function draw_decel(ax, logs)
    cla(ax, 'reset');
    h1 = plot(ax, logs.t_acmd, logs.a_cmd, 'LineWidth', 1.4);
    hold(ax, 'on');
    h2 = plot(ax, logs.t_aact, logs.a_act, 'LineWidth', 1.4);
    hold(ax, 'off');
    style_axes(ax);
    title(ax, '减速度：PID 指令 a_cmd / 实际 a_act');
    xlabel(ax, 't [s]');
    ylabel(ax, '减速度幅值 [m/s²]');
    legend(ax, [h1 h2], {'指令 a_{cmd}', '实际 a_{act}'}, 'Location', 'best');
    xlim(ax, [0, max([logs.t_acmd; logs.t_aact])]);
end

function draw_ttc_state(ax, logs)
    cla(ax, 'reset');
    ttc = logs.TTC;
    ttc(~isfinite(ttc)) = NaN;
    % 接近停稳时 TTC = d/v_rel 会急剧增大，超过 10 s 的部分不显示，
    % 避免把 1~3 s 的决策关注区压扁。
    ttc(ttc > 10) = NaN;

    yyaxis(ax, 'left');
    h1 = plot(ax, logs.t_ttc, ttc, 'LineWidth', 1.4);
    ylabel(ax, 'TTC [s]');
    fin = ttc(isfinite(ttc));
    if isempty(fin)
        ylim(ax, [0 10]);
    else
        ylim(ax, [0, max(3, min(10, max(fin) * 1.1))]);
    end

    yyaxis(ax, 'right');
    h2 = stairs(ax, logs.t_state, logs.state, 'LineWidth', 1.2);
    ylabel(ax, '状态 state');
    ylim(ax, [-0.3 3.3]);
    yticks(ax, 0:3);
    yticklabels(ax, {'0 SAFE', '1 WARNING', '2 PBA', '3 EMERG'});

    style_axes(ax);
    title(ax, 'TTC 与 AEB 状态（0 SAFE / 1 WARNING / 2 PBA / 3 EMERG）');
    xlabel(ax, 't [s]');
    legend(ax, [h1 h2], {'TTC', '状态 state 0/1/2/3'}, 'Location', 'best');
    xlim(ax, [0, max(logs.t_ttc)]);
end

function style_axes(ax)
    ax.FontName = ui_font_name();
    ax.FontSize = 10;
    grid(ax, 'on');
    box(ax, 'off');
end

function save_plots(logs, picDir)
    if ~isfolder(picDir)
        mkdir(picDir);
    end
    names = {'01_gap.png', '02_speed.png', '03_decel.png', '04_ttc_state.png'};
    % 使用隐藏的经典 axes 重新绘制并导出，避免 uiaxes 首次导出时
    % 偶发截取整个 uifigure 的问题；绘制逻辑与界面共用 draw_* 函数。
    fig = figure('Visible', 'off', 'Color', 'w', ...
        'Position', [80 60 900 620]);
    figCleaner = onCleanup(@() close(fig));
    ax = axes(fig);
    for k = 1:4
        switch k
            case 1
                draw_gap(ax, logs);
            case 2
                draw_speed(ax, logs);
            case 3
                draw_decel(ax, logs);
            case 4
                draw_ttc_state(ax, logs);
        end
        exportgraphics(ax, fullfile(picDir, names{k}), 'Resolution', 150);
    end
end

function update_metrics(app, m)
    vals = cell(1, 9);
    vals{1} = sprintf('%.3f', m.d_min);
    vals{2} = sprintf('%.3f', m.d_final);
    vals{3} = sprintf('%.3f', m.a_peak);
    vals{4} = sprintf('%.3f', m.v_final);
    vals{5} = fmt_optional(m.t_stop, '%.2f');
    vals{6} = fmt_optional(m.t_pba, '%.2f');
    if m.collision_mismatch
        vals{7} = [yes_no(m.collision) ' *'];
    else
        vals{7} = yes_no(m.collision);
    end
    if m.collision_inferred
        vals{8} = [fmt_optional(m.impact, '%.2f') ' *'];
    else
        vals{8} = fmt_optional(m.impact, '%.2f');
    end
    if isempty(m.state_seq)
        vals{9} = '--';
    else
        vals{9} = m.state_seq_str;
    end
    for k = 1:9
        app.metricLabels{k}.Text = vals{k};
    end

    if m.collision_inferred
        app.metricLabels{7}.FontColor = [0.85 0.33 0.10];
        app.metricLabels{7}.Tooltip = ...
            'collision 日志未捕获终止采样；按 d<=0 交叉判定为碰撞。';
        app.metricLabels{8}.FontColor = [0.85 0.33 0.10];
        app.metricLabels{8}.Tooltip = ...
            'impact 为第一个 d<=0 时刻对齐 v_ego 的最近采样估算值。';
    elseif m.collision_mismatch
        app.metricLabels{7}.FontColor = [0.85 0.33 0.10];
        app.metricLabels{7}.Tooltip = ...
            '碰撞日志为真，但 d_min>0.05 m，请检查 log_p_wc1 与 log_d。';
        app.metricLabels{8}.FontColor = [0.05 0.25 0.55];
        app.metricLabels{8}.Tooltip = '';
    else
        app.metricLabels{7}.FontColor = [0.05 0.25 0.55];
        app.metricLabels{7}.Tooltip = '';
        app.metricLabels{8}.FontColor = [0.05 0.25 0.55];
        app.metricLabels{8}.Tooltip = '';
    end
end

function s = fmt_optional(v, fmt)
    if isnan(v)
        s = '--';
    else
        s = sprintf(fmt, v);
    end
end

function s = yes_no(tf)
    if tf
        s = '是';
    else
        s = '否';
    end
end

% =====================================================================
% 无界面自检
% =====================================================================
function run_selftest()
    rootDir = gui_root();
    mdl = 'AEB_v1_wzq';
    modelFile = fullfile(rootDir, [mdl '.slx']);

    fprintf('\n===== AEB_GUI selftest =====\n');
    fprintf('MATLAB : %s\n', version);
    fprintf('ROOT   : %s\n', rootDir);
    if ~isfile(modelFile)
        error('AEB_GUI:ModelMissing', '找不到模型文件：%s', modelFile);
    end
    hashBefore = file_sha256(modelFile);
    fprintf('MODEL  : %s\n', modelFile);
    fprintf('SHA256 before : %s\n', hashBefore);

    specs = param_specs();
    params = default_params(specs);
    validate_params(params);

    t0 = tic;
    [metrics, logs] = simulate_model(params);
    elapsed = toc(t0);
    fprintf('SIMULATION    : OK (%.2f s, %d samples, t_end=%.2f s)\n', ...
        elapsed, numel(logs.t_d), logs.t_d(end));

    if any(isnan([metrics.d_min, metrics.d_final, ...
            metrics.a_peak, metrics.v_final]))
        error('AEB_GUI:BadMetrics', '关键指标出现 NaN。');
    end

    fprintf('\n--- 输出指标 ---\n');
    fprintf('d_min      = %.4f m (t = %.2f s)\n', metrics.d_min, metrics.t_dmin);
    fprintf('d_final    = %.4f m\n', metrics.d_final);
    fprintf('a_peak     = %.4f m/s^2\n', metrics.a_peak);
    fprintf('v_final    = %.4f m/s\n', metrics.v_final);
    if isnan(metrics.t_stop)
        fprintf('t_stop     = --\n');
    else
        fprintf('t_stop     = %.3f s\n', metrics.t_stop);
    end
    if isnan(metrics.t_pba)
        fprintf('t_pba      = --\n');
    else
        fprintf('t_pba      = %.3f s\n', metrics.t_pba);
    end
    fprintf('collision  = %d (%s)\n', metrics.collision, yes_no(metrics.collision));
    if metrics.collision_inferred
        fprintf(['impact     = %.4f m/s (t = %.3f s, 估算：首个 d<=0 采样' ...
            '对齐 v_ego)\n'], metrics.impact, metrics.impact_time);
    elseif metrics.collision
        fprintf('impact     = %.4f m/s (t = %.3f s, 碰撞日志)\n', ...
            metrics.impact, metrics.t_collision);
    else
        fprintf('impact     = --\n');
    end
    fprintf('state_seq  = %s\n', metrics.state_seq_str);
    if ~any(metrics.state_seq == 2) || ~any(metrics.state_seq == 3)
        error('AEB_GUI:MissingPbaState', ...
            ['默认工况状态序列未同时包含 PBA(2) 和 EMERGENCY(3)：%s。' ...
             '请检查 TTC_pba / TTC_brake / a_pba_g 与决策锁存逻辑。'], ...
            metrics.state_seq_str);
    end
    if metrics.collision_inferred
        fprintf(['WARNING    : collision 日志未捕获终止采样；已按 d<=0 判定碰撞，' ...
            'impact 为 d<=0 时刻对齐 v_ego 的估算采样。\n']);
    elseif metrics.collision_mismatch
        fprintf(['WARNING    : 碰撞日志为真，但 d_min=%.4f m > 0.05 m；' ...
            '请检查 log_p_wc1 与 log_d。\n'], metrics.d_min);
    end

    picDir = fullfile(rootDir, 'picture');
    if ~isfolder(picDir)
        mkdir(picDir);
    end

    save_plots(logs, picDir);
    drawnow;

    names = {'01_gap.png', '02_speed.png', '03_decel.png', '04_ttc_state.png'};
    fprintf('\n--- 图片 ---\n');
    for k = 1:4
        f = fullfile(picDir, names{k});
        if ~isfile(f)
            error('AEB_GUI:MissingPicture', '未生成图片：%s', f);
        end
        info = dir(f);
        if info.bytes <= 0
            error('AEB_GUI:EmptyPicture', '图片为空：%s', f);
        end
        im = imfinfo(f);
        fprintf('%s : %d bytes, %dx%d px', ...
            names{k}, info.bytes, im.Width, im.Height);
        try
            if isfield(im, 'XResolution') && ~isempty(im.XResolution)
                res = im.XResolution(1);
                if isfield(im, 'ResolutionUnit') && strcmpi(im.ResolutionUnit, 'meter')
                    dpi = res * 0.0254;   % px/m -> px/inch
                else
                    dpi = res;
                end
                fprintf(', %.0f dpi', dpi);
                if isfinite(dpi) && dpi < 149.5
                    error('AEB_GUI:LowDpi', ...
                        '图片分辨率低于 150 dpi：%s（%.1f dpi）', f, dpi);
                end
            end
        catch errDpi
            if strcmp(errDpi.identifier, 'AEB_GUI:LowDpi')
                rethrow(errDpi);
            end
        end
        fprintf('\n');
    end

    hashAfter = file_sha256(modelFile);
    fprintf('\nSHA256 after  : %s\n', hashAfter);
    if isempty(hashBefore) || isempty(hashAfter)
        warning('AEB_GUI:HashUnavailable', '无法计算 SHA-256，跳过模型哈希核对。');
    elseif ~strcmpi(hashBefore, hashAfter)
        error('AEB_GUI:ModelChanged', '模型文件哈希发生变化：%s', modelFile);
    else
        fprintf('MODEL UNCHANGED: YES\n');
    end

    fprintf('\nSELFTEST PASS\n');
end

% =====================================================================
% 参数表
% =====================================================================
function specs = param_specs()
    rows = {
        'v_ego0_kmh',   '场景',     '自车初速',           'km/h',          40,    0,     200,  'numeric', false, 'AEB_v1_wzq/自车状态 Vehicle/Integrator_v';
        'gap0',         '场景',     '初始净车距',         'm',             60,    0.1,   5000, 'numeric', false, 'AEB_v1_wzq/传感器/场景参数向量 ScenarioParams [初始距离，初速度，加速度，刹车时间]';
        'v_target0_kmh','场景',     '目标车初速',         'km/h',          0,     0,     200,  'numeric', false, 'AEB_v1_wzq/传感器/场景参数向量 ScenarioParams [初始距离，初速度，加速度，刹车时间]';
        'a_target',     '场景',     '目标车加速度',       'm/s²',          0,     -15,   5,    'numeric', false, 'AEB_v1_wzq/传感器/场景参数向量 ScenarioParams [初始距离，初速度，加速度，刹车时间]';
        't_brake',      '场景',     '目标车变速时刻',     's',             Inf,   0,     10,   'text',    false, 'AEB_v1_wzq/传感器/场景参数向量 ScenarioParams [初始距离，初速度，加速度，刹车时间]';
        'mu',           '场景',     '路面附着系数',       '-',             0.8,   0.01,  2,    'numeric', false, 'AEB_v1_wzq/风险计算/路面附着系数mu';
        'a_brake_g',    '风险与决策', '目标制动强度',     'g',             0.7,   0.01,  2,    'numeric', false, 'AEB_v1_wzq/风险计算/目标制动减速度 a_brake_g';
        'a_pba_g',      '风险与决策', '部分制动强度',     'g',             0.3,   0.01,  2,    'numeric', false, 'AEB_v1_wzq/决策/部分制动强度 a_pba_g';
        'd_margin',     '风险与决策', '停车距离余量',     'm',             2,     0,     100,  'numeric', false, 'AEB_v1_wzq/风险计算/停车余量 d_margin';
        'TTC_warn',     '风险与决策', '预警 TTC 阈值',    's',             2.4,   0.01,  30,   'numeric', false, 'AEB_v1_wzq/决策/预警阈值 TTC_warn';
        'TTC_pba',      '风险与决策', '部分制动 TTC 阈值','s',             2.0,   0.01,  30,   'numeric', false, 'AEB_v1_wzq/决策/部分制动阈值 TTC_pba';
        'TTC_brake',    '风险与决策', '制动进入 TTC',     's',             1.6,   0.01,  30,   'numeric', false, 'AEB_v1_wzq/决策/制动进入阈值 TTC_brake';
        'TTC_brake_off','风险与决策', '制动退出 TTC',     's',             2,     0.01,  30,   'numeric', false, 'AEB_v1_wzq/决策/制动阈值 TTC_brake_off';
        'v_stop',       '风险与决策', '停稳速度阈值',     'm/s',           0.3,   0,     5,    'numeric', false, 'AEB_v1_wzq/决策/ 停稳判定阈值 v_stop';
        'Kp',           'PID',      '比例增益 Kp',        '-',             2,     0,     100,  'numeric', false, 'AEB_v1_wzq/PID/内部参数 PidParams [Kp, Ki, Kd, Ts]';
        'Ki',           'PID',      '积分增益 Ki',        '1/s',           5,     0,     500,  'numeric', false, 'AEB_v1_wzq/PID/内部参数 PidParams [Kp, Ki, Kd, Ts]';
        'Kd',           'PID',      '微分增益 Kd',        's',             0,     0,     100,  'numeric', false, 'AEB_v1_wzq/PID/内部参数 PidParams [Kp, Ki, Kd, Ts]';
        'Ts',           'PID',      '离散周期 Ts',        's',             0.01,  0.01,  0.01, 'numeric', true,  'AEB_v1_wzq/PID/内部参数 PidParams [Kp, Ki, Kd, Ts]';
        'k_dec',        '执行机构',  '压力-减速度系数',   '(m/s²)/压力',   0.08,  0.001, 10,   'numeric', false, 'AEB_v1_wzq/执行机构 主缸助力电机液压/ActParams';
        'tau_fill',     '执行机构',  '轮缸充压时间常数',  's',             0.04,  0.001, 5,    'numeric', false, 'AEB_v1_wzq/执行机构 主缸助力电机液压/ActParams';
        'tau_rel',      '执行机构',  '轮缸卸压时间常数',  's',             0.05,  0.001, 5,    'numeric', false, 'AEB_v1_wzq/执行机构 主缸助力电机液压/ActParams';
    };
    specs = cell2struct(rows, ...
        {'key', 'group', 'label', 'unit', 'default', 'min', 'max', ...
         'type', 'readonly', 'block'}, 2);
end

function p = default_params(specs)
    p = struct();
    for k = 1:numel(specs)
        p.(specs(k).key) = specs(k).default;
    end
end

% =====================================================================
% 杂项工具
% =====================================================================
function rootDir = gui_root()
    rootDir = fileparts(mfilename('fullpath'));
    if isempty(rootDir)
        rootDir = pwd;
    end
end

function fname = ui_font_name()
    persistent cached
    if ~isempty(cached)
        fname = cached;
        return;
    end
    fname = 'Microsoft YaHei';
    try
        fonts = listfonts;
        if ~any(strcmpi(fonts, fname))
            fname = get(groot, 'defaultAxesFontName');
        end
    catch
        fname = 'Helvetica';
    end
    cached = fname;
end

function h = file_sha256(f)
    h = '';
    try
        md = java.security.MessageDigest.getInstance('SHA-256');
        fid = fopen(f, 'r');
        if fid < 0
            return;
        end
        fileCleaner = onCleanup(@() fclose(fid));
        while true
            b = fread(fid, 65536, '*uint8');
            if isempty(b)
                break;
            end
            md.update(b);
        end
        dig = typecast(md.digest(), 'uint8');
        h = lower(reshape(dec2hex(dig, 2).', 1, []));
    catch
        h = '';
    end
end
