# -*- coding: utf-8 -*-
# @static-doc
# 作用：工业蓝图线稿的外层批处理 CLI；为每个 `.blend` / `.glb` 启动独立 Blender 后台进程，
# 使单件导入或渲染失败不会污染、阻断其它模型，并汇总日志与 `batch_summary.json`。
#
# ## 契约与约束
# - 文件输入直接写到 `--output`；目录输入按相对路径建立子目录，避免递归扫描时同名冲突。
# - 每件模型拥有独立 `blueprint.log`；批次退出码在任一任务失败时为 1，但仍处理完整清单。
# - 本脚本只依赖 Python 标准库；Blender 路径可显式传入或通过 `BLENDER_BIN` / PATH 发现。
# @end-static-doc

import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys


SUPPORTED_INPUTS = {".blend", ".glb"}


def _parser():
    parser = argparse.ArgumentParser(description="Batch Blender blueprint line-art generation.")
    parser.add_argument("--input", required=True, help="A model file or directory")
    parser.add_argument("--output", required=True, help="Output directory")
    parser.add_argument("--blender", help="Blender executable; otherwise BLENDER_BIN or PATH")
    parser.add_argument("--recursive", action="store_true", help="Recurse into input directory")
    parser.add_argument("--views", default="side,top,iso")
    parser.add_argument("--detail", choices=("simple", "normal", "detailed"), default="normal")
    parser.add_argument("--resolution", type=int)
    parser.add_argument("--margin", type=float)
    parser.add_argument("--forward-axis", default="+X")
    parser.add_argument("--up-axis", default="+Z")
    parser.add_argument("--config")
    parser.add_argument("--no-crop", action="store_true")
    parser.add_argument("--crop-padding", type=float)
    parser.add_argument("--crop-alpha-threshold", type=int)
    return parser


def _find_blender(explicit):
    candidate = explicit or os.environ.get("BLENDER_BIN") or shutil.which("blender")
    if not candidate:
        raise FileNotFoundError("Blender not found; pass --blender or set BLENDER_BIN")
    resolved = os.path.abspath(candidate) if os.path.exists(candidate) else shutil.which(candidate)
    if not resolved or not os.path.isfile(resolved):
        raise FileNotFoundError("Blender executable not found: %s" % candidate)
    return resolved


def _discover(source, recursive):
    if source.is_file():
        if source.suffix.lower() not in SUPPORTED_INPUTS:
            raise ValueError("input must be .blend or .glb")
        return [source]
    if not source.is_dir():
        raise FileNotFoundError(str(source))
    iterator = source.rglob("*") if recursive else source.glob("*")
    return sorted((path for path in iterator if path.is_file() and path.suffix.lower() in SUPPORTED_INPUTS),
                  key=lambda path: str(path).lower())


def _target_dir(source, model, output):
    if source.is_file():
        return output
    relative = model.relative_to(source)
    # Keep the extension in the directory name so `ship.blend` and `ship.glb`
    # can coexist in one recursive batch without overwriting each other.
    return output / relative.parent / relative.name


def _atomic_json(path, value):
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
                         encoding="utf-8")
    os.replace(str(temporary), str(path))


def run(args):
    blender = _find_blender(args.blender)
    source = Path(args.input).resolve()
    output = Path(args.output).resolve()
    output.mkdir(parents=True, exist_ok=True)
    models = _discover(source, args.recursive)
    if not models:
        raise ValueError("no .blend or .glb files found")
    generator = Path(__file__).with_name("blueprint_generator.py").resolve()
    results = []
    for model in models:
        target = _target_dir(source, model, output)
        target.mkdir(parents=True, exist_ok=True)
        command = [
            blender, "-b", "-P", str(generator), "--",
            "--input", str(model), "--output", str(target),
            "--views", args.views, "--detail", args.detail,
            "--forward-axis", args.forward_axis, "--up-axis", args.up_axis,
        ]
        if args.resolution is not None:
            command.extend(("--resolution", str(args.resolution)))
        if args.margin is not None:
            command.extend(("--margin", str(args.margin)))
        if args.config:
            command.extend(("--config", str(Path(args.config).resolve())))
        if args.no_crop:
            command.append("--no-crop")
        if args.crop_padding is not None:
            command.extend(("--crop-padding", str(args.crop_padding)))
        if args.crop_alpha_threshold is not None:
            command.extend(("--crop-alpha-threshold", str(args.crop_alpha_threshold)))
        print("[blueprint] %s -> %s" % (model, target), flush=True)
        completed = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                   text=True, encoding="utf-8", errors="replace", check=False)
        log_path = target / "blueprint.log"
        log_path.write_text(completed.stdout, encoding="utf-8")
        result = {
            "input": str(model),
            "output": str(target),
            "exit_code": completed.returncode,
            "status": "ok" if completed.returncode == 0 else "failed",
            "log": str(log_path),
        }
        results.append(result)
        print("[blueprint] %s (%s)" % (result["status"], model.name), flush=True)
    summary = {
        "schema_version": 1,
        "total": len(results),
        "succeeded": sum(result["status"] == "ok" for result in results),
        "failed": sum(result["status"] == "failed" for result in results),
        "results": results,
    }
    _atomic_json(output / "batch_summary.json", summary)
    return 1 if summary["failed"] else 0


def main():
    args = _parser().parse_args()
    try:
        return run(args)
    except Exception as error:
        print("[blueprint] fatal: %s" % error, file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
