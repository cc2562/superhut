#!/bin/bash

# SuperHUT iOS 构建脚本
# 用于自动化构建无签名的 iOS ipa 安装包
#
# 使用方法:
#   ./build_ios.sh          # 完整构建流程
#   ./build_ios.sh --quick  # 快速模式，跳过清理
#   ./build_ios.sh --resume # 恢复模式，从中断处继续
#
# 选项说明:
#   --quick, -q    快速构建，跳过清理和依赖安装
#   --resume, -r   恢复构建，从上次中断处继续
#   --help, -h     显示帮助信息

set -e  # 遇到错误时立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 打印带颜色的消息
print_message() {
    echo -e "${2}$1${NC}"
}

print_success() {
    print_message "✅ $1" "$GREEN"
}

print_warning() {
    print_message "⚠️  $1" "$YELLOW"
}

print_error() {
    print_message "❌ $1" "$RED"
}

print_info() {
    print_message "ℹ️  $1" "$BLUE"
}

# 获取项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# 版本信息
VERSION=$(grep "version:" "$PROJECT_ROOT/pubspec.yaml" | awk '{print $2}' | tr -d '\r')
APP_NAME="superhut"

# 输出目录
BUILD_DIR="$PROJECT_ROOT/build"
IOS_BUILD_DIR="$BUILD_DIR/ios"
IPA_DIR="$IOS_BUILD_DIR/ipa"
OUTPUT_DIR="$PROJECT_ROOT/releases"

print_info "开始构建 SuperHUT iOS 应用 v$VERSION"
print_info "项目根目录: $PROJECT_ROOT"

# 检查环境
check_environment() {
    print_info "检查构建环境..."
    
    # 检查 Flutter
    if ! command -v flutter &> /dev/null; then
        print_error "Flutter 未安装或未添加到 PATH"
        exit 1
    fi
    
    # 检查 CocoaPods
    if ! command -v pod &> /dev/null; then
        print_error "CocoaPods 未安装"
        print_info "请运行: brew install cocoapods"
        exit 1
    fi
    
    # 检查 Xcode
    if ! command -v xcodebuild &> /dev/null; then
        print_error "Xcode 未安装或命令行工具未配置"
        exit 1
    fi
    
    print_success "环境检查通过"
}

# 清理构建目录
clean_build() {
    print_info "清理构建缓存..."
    cd "$PROJECT_ROOT"
    
    flutter clean > /dev/null 2>&1
    
    # 清理 iOS 构建文件
    if [ -d "$IOS_BUILD_DIR" ]; then
        rm -rf "$IOS_BUILD_DIR"
        print_success "已清理 iOS 构建目录"
    fi
    
    # 清理 Pods
    if [ -d "$PROJECT_ROOT/ios/Pods" ]; then
        rm -rf "$PROJECT_ROOT/ios/Pods"
        print_success "已清理 CocoaPods 缓存"
    fi
    
    if [ -f "$PROJECT_ROOT/ios/Podfile.lock" ]; then
        rm "$PROJECT_ROOT/ios/Podfile.lock"
    fi
}

# 获取依赖
get_dependencies() {
    print_info "获取 Flutter 依赖..."
    cd "$PROJECT_ROOT"
    
    flutter pub get
    
    if [ $? -eq 0 ]; then
        print_success "依赖获取完成"
    else
        print_error "依赖获取失败"
        exit 1
    fi
}

# 预缓存 iOS 引擎
precache_ios() {
    print_info "下载 iOS 引擎文件..."
    
    flutter precache --ios
    
    if [ $? -eq 0 ]; then
        print_success "iOS 引擎文件下载完成"
    else
        print_error "iOS 引擎文件下载失败"
        exit 1
    fi
}

# 安装 CocoaPods 依赖
install_pods() {
    print_info "安装 CocoaPods 依赖..."
    cd "$PROJECT_ROOT/ios"
    
    pod install --repo-update
    
    if [ $? -eq 0 ]; then
        print_success "CocoaPods 依赖安装完成"
    else
        print_error "CocoaPods 依赖安装失败"
        exit 1
    fi
}

# 构建 iOS 应用
build_ios_app() {
    print_info "构建 iOS 应用..."
    cd "$PROJECT_ROOT"
    
    print_info "开始 Flutter iOS 构建，这可能需要几分钟时间..."
    flutter build ios --no-codesign --release
    
    # 检查构建是否成功
    if [ $? -eq 0 ]; then
        # 验证 Runner.app 是否存在
        if [ -d "$IOS_BUILD_DIR/iphoneos/Runner.app" ]; then
            print_success "iOS 应用构建完成"
        else
            print_error "构建完成但找不到 Runner.app 文件"
            print_error "预期路径: $IOS_BUILD_DIR/iphoneos/Runner.app"
            exit 1
        fi
    else
        print_error "iOS 应用构建失败"
        exit 1
    fi
}

# 创建 IPA 包
create_ipa() {
    print_info "创建 IPA 安装包..."
    
    # 检查 Runner.app 是否存在
    APP_PATH="$IOS_BUILD_DIR/iphoneos/Runner.app"
    if [ ! -d "$APP_PATH" ]; then
        print_error "找不到 Runner.app 文件: $APP_PATH"
        print_error "请确保 iOS 构建成功完成"
        exit 1
    fi
    
    # 创建必要的目录
    mkdir -p "$IPA_DIR/Payload"
    mkdir -p "$OUTPUT_DIR"
    
    # 复制应用文件
    print_info "复制应用文件到 Payload 目录..."
    cp -r "$APP_PATH" "$IPA_DIR/Payload/"
    
    if [ $? -ne 0 ]; then
        print_error "复制应用文件失败"
        exit 1
    fi
    
    # 生成 IPA 文件名
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    IPA_FILENAME="${APP_NAME}-v${VERSION}-unsigned-${TIMESTAMP}.ipa"
    IPA_PATH="$OUTPUT_DIR/$IPA_FILENAME"
    
    # 创建 IPA 包
    print_info "打包 IPA 文件..."
    cd "$IPA_DIR"
    zip -r "$IPA_PATH" Payload > /dev/null
    
    if [ $? -eq 0 ] && [ -f "$IPA_PATH" ]; then
        print_success "IPA 包创建完成"
        
        # 获取文件大小
        FILE_SIZE=$(ls -lh "$IPA_PATH" | awk '{print $5}')
        
        print_info "📦 安装包信息:"
        print_info "   文件名: $IPA_FILENAME"
        print_info "   大小: $FILE_SIZE"
        print_info "   路径: $IPA_PATH"
    else
        print_error "IPA 包创建失败"
        exit 1
    fi
}

# 清理临时文件
cleanup_temp() {
    print_info "清理临时文件..."
    
    if [ -d "$IPA_DIR" ]; then
        rm -rf "$IPA_DIR"
    fi
    
    print_success "临时文件清理完成"
}

# 显示构建结果
show_result() {
    print_success "🎉 SuperHUT iOS 应用构建完成！"
    echo
    print_info "📱 应用信息:"
    print_info "   应用名称: SuperHUT"
    print_info "   版本号: $VERSION"
    print_info "   构建时间: $(date)"
    echo
    print_info "📦 安装包位置:"
    print_info "   $IPA_PATH"
    echo
    print_warning "⚠️  注意事项:"
    print_warning "   - 此为无签名 IPA 包，无法通过 App Store 安装"
    print_warning "   - 需要通过开发者工具或第三方工具安装"
    print_warning "   - 支持工具: Xcode、AltStore、3uTools 等"
    echo
    print_info "🚀 安装方法:"
    print_info "   1. 使用 Xcode: Devices and Simulators -> 拖拽 IPA 文件"
    print_info "   2. 使用 AltStore: 直接安装到设备"
    print_info "   3. 使用命令行: ios-deploy --bundle 路径"
}

# 显示帮助信息
show_help() {
    echo "SuperHUT iOS 构建脚本 v1.0"
    echo ""
    echo "用法:"
    echo "  $0 [选项]"
    echo ""
    echo "选项:"
    echo "  无参数       执行完整构建流程（推荐首次使用）"
    echo "  --quick, -q  快速构建模式，跳过清理和依赖安装"
    echo "  --resume, -r 恢复构建模式，从上次中断处继续"
    echo "  --help, -h   显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0                # 完整构建"
    echo "  $0 --quick        # 快速构建"
    echo "  $0 --resume       # 恢复构建"
    echo ""
    echo "注意:"
    echo "  - 首次使用建议执行完整构建"
    echo "  - 如果构建被中断，可使用 --resume 选项继续"
    echo "  - 快速模式适用于代码未变更时的重新打包"
}

# 主函数
main() {
    # 切换到项目根目录
    cd "$PROJECT_ROOT"
    
    # 处理帮助选项
    if [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        show_help
        exit 0
    fi
    
    print_info "========================================"
    print_info "     SuperHUT iOS 构建脚本 v1.0"
    print_info "========================================"
    echo
    
    # 检查是否有参数
    if [ "$1" = "--quick" ] || [ "$1" = "-q" ]; then
        print_warning "快速模式: 跳过清理和依赖安装"
        echo
        
        check_environment
        
        # 检查是否已有构建结果
        if [ -d "$IOS_BUILD_DIR/iphoneos/Runner.app" ]; then
            print_success "发现已存在的构建结果，直接创建 IPA"
            create_ipa
            show_result
            return
        fi
        
        build_ios_app
        create_ipa
        cleanup_temp
        show_result
    elif [ "$1" = "--resume" ] || [ "$1" = "-r" ]; then
        print_warning "恢复模式: 从上次中断处继续"
        echo
        
        check_environment
        
        # 检查构建状态并决定从哪里继续
        if [ -d "$IOS_BUILD_DIR/iphoneos/Runner.app" ]; then
            print_info "发现完整的构建结果，创建 IPA"
            create_ipa
        else
            print_info "需要重新构建应用"
            build_ios_app
            create_ipa
        fi
        
        cleanup_temp
        show_result
    else
        # 完整构建流程
        check_environment
        clean_build
        get_dependencies
        precache_ios
        install_pods
        build_ios_app
        create_ipa
        cleanup_temp
        show_result
    fi
    
    echo
    print_success "✨ 构建流程全部完成！"
}

# 错误处理
trap 'print_error "构建过程中发生错误，请检查上面的错误信息"; exit 1' ERR

# 执行主函数
main "$@"
