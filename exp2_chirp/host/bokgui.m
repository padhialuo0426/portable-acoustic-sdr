function varargout = bokgui(varargin)
% BOKGUI MATLAB code for bokgui.fig
%      BOKGUI, by itself, creates a new BOKGUI or raises the existing
%      singleton*.
%
%      H = BOKGUI returns the handle to a new BOKGUI or the handle to
%      the existing singleton*.
%
%      BOKGUI('CALLBACK',hObject,eventData,handles,...) calls the local
%      function named CALLBACK in BOKGUI.M with the given input arguments.
%
%      BOKGUI('Property','Value',...) creates a new BOKGUI or raises the
%      existing singleton*.  Starting from the left, property value pairs are
%      applied to the GUI before bokgui_OpeningFcn gets called.  An
%      unrecognized property name or invalid value makes property application
%      stop.  All inputs are passed to bokgui_OpeningFcn via varargin.
%
%      *See GUI Options on GUIDE's Tools menu.  Choose "GUI allows only one
%      instance to run (singleton)".
%
% See also: GUIDE, GUIDATA, GUIHANDLES

% Edit the above text to modify the response to help bokgui

% Last Modified by GUIDE v2.5 21-Jun-2024 17:58:58

% Begin initialization code - DO NOT EDIT
gui_Singleton = 1;
gui_State = struct('gui_Name',       mfilename, ...
                   'gui_Singleton',  gui_Singleton, ...
                   'gui_OpeningFcn', @bokgui_OpeningFcn, ...
                   'gui_OutputFcn',  @bokgui_OutputFcn, ...
                   'gui_LayoutFcn',  [] , ...
                   'gui_Callback',   []);
if nargin && ischar(varargin{1})
    gui_State.gui_Callback = str2func(varargin{1});
end

if nargout
    [varargout{1:nargout}] = gui_mainfcn(gui_State, varargin{:});
else
    gui_mainfcn(gui_State, varargin{:});
end
% End initialization code - DO NOT EDIT


% --- Executes just before bokgui is made visible.
function bokgui_OpeningFcn(hObject, eventdata, handles, varargin)
% This function has no output args, see OutputFcn.
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
% varargin   command line arguments to bokgui (see VARARGIN)

% Choose default command line output for bokgui
handles.output = hObject;

% Update handles structure
guidata(hObject, handles);

% UIWAIT makes bokgui wait for user response (see UIRESUME)
% uiwait(handles.figure1);


% --- Outputs from this function are returned to the command line.
function varargout = bokgui_OutputFcn(hObject, eventdata, handles) 
% varargout  cell array for returning output args (see VARARGOUT);
% hObject    handle to figure
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Get default command line output from handles structure
varargout{1} = handles.output;


% % 打开接收端simulink程序
function pushbutton1_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
chirp_rev_detect

% 运行电脑MATLAB发送端.m程序
function pushbutton2_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton2 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
Bok_emit
axes(handles.axes1); % 设置当前绘图区域为axes1
cla; % 清空绘图区域
imshow(imdata);
title('电脑发送图片')
% Bok_emit

% 从树莓派取回 chirp5.mat：移植后改用标准 scp/FileZilla，不再用 :6666 TCP
function pushbutton3_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton3 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
helpdlg(sprintf(['取文件请用 scp 或 FileZilla(本界面“打开FileZilla”按钮):\n\n', ...
    '  scp pi@<板子IP>:.../exp2_chirp/chirp5.mat .\n\n', ...
    '拷到本目录后再点“接收端处理”运行 Bok_rev。\n', ...
    '(旧的 :6666 TCP client.m 已废弃删除)']), '取回 chirp5.mat');

% 运行电脑MATLAB接收端处理程序
function pushbutton4_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton4 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
Bok_rev
axes(handles.axes2); % 设置当前绘图区域为axes2
cla;
imshow(logical(bmp_figure));
title('树莓派接收图片')
set(handles.edit1,'string',num2str(BER));


function edit1_Callback(hObject, eventdata, handles)
% hObject    handle to edit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)

% Hints: get(hObject,'String') returns contents of edit1 as text
%        str2double(get(hObject,'String')) returns contents of edit1 as a double


% --- Executes during object creation, after setting all properties.
function edit1_CreateFcn(hObject, eventdata, handles)
% hObject    handle to edit1 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    empty - handles not created until after all CreateFcns called

% Hint: edit controls usually have a white background on Windows.
%       See ISPC and COMPUTER.
if ispc && isequal(get(hObject,'BackgroundColor'), get(0,'defaultUicontrolBackgroundColor'))
    set(hObject,'BackgroundColor','white');
end

% 打开FileZilla软件，连接树莓派回传文件
% --- Executes on button press in pushbutton5.
function pushbutton5_Callback(hObject, eventdata, handles)
% hObject    handle to pushbutton5 (see GCBO)
% eventdata  reserved - to be defined in a future version of MATLAB
% handles    structure with handles and user data (see GUIDATA)
dos('D:\Program Files\FileZilla FTP Client\filezilla.exe')%FileZilla软件的安装路径