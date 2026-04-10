# main.py
from fastapi import FastAPI
from pydantic import BaseModel
from typing import Optional
import uvicorn

# 创建 FastAPI 应用
app = FastAPI(
    title="简单Python后端服务",
    description="一个只有一个接口的示例后端",
    version="1.0.0"
)

# 定义请求体模型（可选）
class HelloRequest(BaseModel):
    name: Optional[str] = "朋友"
    age: Optional[int] = None

# ==================== 接口 ====================

@app.get("/")
async def root():
    """根路径欢迎接口"""
    return {
        "message": "欢迎使用我的Python后端服务！",
        "status": "running",
        "tips": "访问 /docs 查看接口文档"
    }


@app.get("/hello")
async def hello(name: str = "朋友"):
    """最简单的GET示例接口"""
    return {
        "code": 200,
        "message": f"你好，{name}！",
        "data": {
            "greeting": f"Hello, {name}!",
            "time": "现在时间是服务端时间"
        }
    }


@app.post("/hello")
async def hello_post(request: HelloRequest):
    """POST示例接口（带请求体）"""
    greeting = f"你好，{request.name}！"
    if request.age:
        greeting += f" 你今年 {request.age} 岁了呀~"

    return {
        "code": 200,
        "message": greeting,
        "data": request.dict()
    }


# ==================== 启动服务 ====================
if __name__ == "__main__":
    print("🚀 服务启动中...")
    print("访问地址: http://127.0.0.1:8000")
    print("接口文档: http://127.0.0.1:8000/docs")
    uvicorn.run("main:app",
                host="0.0.0.0",
                port=8000,
                reload=True)
