set MSVC_TOOL_PATH="C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC\14.36.32532\bin\Hostx64\x64"
set Z7_PATH="C:\Program Files\7-Zip"
set ORIGINAL_WORK_DIR=%CD%

set DEPOT_TOOLS=depot_tools
if exist %DEPOT_TOOLS%\ goto skip_depot_install

echo "### Download depot tools..."

set DEPOT_TOOLS_URL=https://storage.googleapis.com/chrome-infra/%DEPOT_TOOLS%.zip
if exist %DEPOT_TOOLS%.zip (curl -kLO %DEPOT_TOOLS_URL% -f --retry 5 -z %DEPOT_TOOLS%.zip) else (curl -kLO %DEPOT_TOOLS_URL% -f --retry 5 -C -)

if %errorlevel% neq 0 exit /b %errorlevel%

powershell -command "Expand-Archive -Force '%~dp0%DEPOT_TOOLS%.zip' '%DEPOT_TOOLS%'"

if %errorlevel% neq 0 exit /b %errorlevel%

:skip_depot_install

set PATH=%ORIGINAL_WORK_DIR%\%DEPOT_TOOLS%\;%PATH%
set DEPOT_TOOLS_WIN_TOOLCHAIN=0

set CHECKOUT_DIR=%ORIGINAL_WORK_DIR%\webrtc-checkout
if exist %CHECKOUT_DIR%\ goto skip_webrtc_checkout 

echo "### Webrtc checkout..."

mkdir %CHECKOUT_DIR%
cd %CHECKOUT_DIR%
call fetch --nohooks webrtc
call gclient sync

if %errorlevel% neq 0 exit /b %errorlevel%

set SRC_DIR=%CHECKOUT_DIR%\src

set WEBRTC_BRANCH=m120
set WEBRTC_BRANCH_PATH=refs/remotes/branch-heads/6099

cd %SRC_DIR%
call git checkout -b %WEBRTC_BRANCH% %WEBRTC_BRANCH_PATH%
call gclient sync -D

if %errorlevel% neq 0 exit /b %errorlevel%

:skip_webrtc_checkout

cd %SRC_DIR%

set BUILD_DIR=%SRC_DIR%\out\%WEBRTC_BRANCH%
if exist %BUILD_DIR%\ goto skip_webrtc_build 

echo "### Webrtc building..."

call gn gen out\%WEBRTC_BRANCH% --args="is_debug=false is_component_build=false is_clang=true rtc_include_tests=true use_rtti=true rtc_build_examples=false use_custom_libcxx=false enable_iterator_debugging=false libcxx_is_shared=false rtc_build_tools=false use_lld=false treat_warnings_as_errors=false  use_custom_libcxx_for_host=false target_os=\"win\" target_cpu=\"x64\""
if %errorlevel% neq 0 exit /b %errorlevel%

call ninja -j6 -C out\%WEBRTC_BRANCH% 
if %errorlevel% neq 0 exit /b %errorlevel%

:skip_webrtc_build

cd %ORIGINAL_WORK_DIR%

REM set PACKAGE_FOLDER_NAME=webrtc-%WEBRTC_BRANCH%-windows-x64
set PACKAGE_FOLDER_NAME=webrtc_dist
set PACKAGE_DIR=%ORIGINAL_WORK_DIR%\%PACKAGE_FOLDER_NAME%
if exist %PACKAGE_DIR%\ goto skip_copying 

echo "### Copying package files..."

del /f excluded.txt
echo \.git\ >> excluded.txt
echo \third_party\depot_tools\ >> excluded.txt

mkdir %PACKAGE_DIR%
xcopy "%SRC_DIR%\*.h" "%PACKAGE_DIR%" /sy /exclude:excluded.txt

echo f | xcopy "%SRC_DIR%\api\test\create_frame_generator.cc" "%PACKAGE_DIR%\api\test\create_frame_generator.cc" /yf
echo f | xcopy "%SRC_DIR%\media\base\fake_frame_source.cc" "%PACKAGE_DIR%\media\base\fake_frame_source.cc" /yf
echo f | xcopy "%SRC_DIR%\pc\test\fake_audio_capture_module.cc" "%PACKAGE_DIR%\pc\test\fake_audio_capture_module.cc" /yf
echo f | xcopy "%SRC_DIR%\rtc_base\task_queue_for_test.cc" "%PACKAGE_DIR%\rtc_base\task_queue_for_test.cc" /yf
echo f | xcopy "%SRC_DIR%\test\frame_generator.cc" "%PACKAGE_DIR%\test\frame_generator.cc" /yf
echo f | xcopy "%SRC_DIR%\test\frame_generator_capturer.cc" "%PACKAGE_DIR%\test\frame_generator_capturer.cc" /yf
echo f | xcopy "%SRC_DIR%\test\frame_utils.cc" "%PACKAGE_DIR%\test\frame_utils.cc" /yf
echo f | xcopy "%SRC_DIR%\test\test_video_capturer.cc" "%PACKAGE_DIR%\test\test_video_capturer.cc" /yf
echo f | xcopy "%SRC_DIR%\test\testsupport\file_utils.cc" "%PACKAGE_DIR%\test\testsupport\file_utils.cc" /yf
echo f | xcopy "%SRC_DIR%\test\testsupport\file_utils_override.cc" "%PACKAGE_DIR%\test\testsupport\file_utils_override.cc" /yf
echo f | xcopy "%SRC_DIR%\test\testsupport\ivf_video_frame_generator.cc" "%PACKAGE_DIR%\test\testsupport\ivf_video_frame_generator.cc" /yf
echo f | xcopy "%SRC_DIR%\test\vcm_capturer.cc" "%PACKAGE_DIR%\test\vcm_capturer.cc" /yf

%MSVC_TOOL_PATH%\lib.exe /out:"%PACKAGE_DIR%\webrtc.lib" ^
  "%BUILD_DIR%\obj\webrtc.lib" ^
  "%BUILD_DIR%\obj\api\video_codecs\builtin_video_encoder_factory.lib" ^
  "%BUILD_DIR%\obj\api\video_codecs\builtin_video_decoder_factory.lib" ^
  "%BUILD_DIR%\obj\media\rtc_internal_video_codecs.lib" ^
  "%BUILD_DIR%\obj\media\rtc_simulcast_encoder_adapter.lib"

:skip_copying

cd %ORIGINAL_WORK_DIR%

echo "### 7z-ing..."

set PACKAGE_FILE=webrtc-%WEBRTC_BRANCH%-windows-x64.7z
%Z7_PATH%\7z.exe a %PACKAGE_FILE% %PACKAGE_FOLDER_NAME%
