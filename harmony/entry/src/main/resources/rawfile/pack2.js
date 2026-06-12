// ==UserScript==
// @name         爆改新能源5.0Pack2
// @namespace    http://tampermonkey.net/
// @version      2.2.0
// @description  护眼、修复了缩放中心点、手写笔拖拽防误触以及悬浮按钮触发问题
// @author       程序猿
// @match        *://*/pdf/web*
// @match        *://*/*/pdf/web*
// @grant        GM_addStyle
// @run-at       document-end
// ==/UserScript==

(function() {
    'use strict';
      if (window.__better_xny_pack2_injected__) {
            console.log("检测到 Pack2 已注入，本次将跳过。");
            return; 
        }
        window.__better_xny_pack2_injected__ = true;
    const featureLimit = 1; 

    // ================= [图标配置区] =================
    const ICONS = {
        sidebar:  'data:image/svg+xml;base64,PHN2ZyB2ZXJzaW9uPSIxLjEiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgeG1sbnM6eGxpbms9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkveGxpbmsiIHdpZHRoPSIxMy4yNSIgaGVpZ2h0PSIxMy4yNSIgdmlld0JveD0iMCwwLDEzLjI1LDEzLjI1Ij48ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSgtMjMzLjM3NSwtMTczLjM3NSkiPjxnIHN0cm9rZS1taXRlcmxpbWl0PSIxMCI+PHBhdGggZD0iTTIzMy4zNzUsMTgwYzAsLTMuNjU4ODggMi45NjYxMiwtNi42MjUgNi42MjUsLTYuNjI1YzMuNjU4ODgsMCA2LjYyNSwyLjk2NjEyIDYuNjI1LDYuNjI1YzAsMy42NTg4OCAtMi45NjYxMiw2LjYyNSAtNi42MjUsNi42MjVjLTMuNjU4ODgsMCAtNi42MjUsLTIuOTY2MTIgLTYuNjI1LC02LjYyNXoiIGZpbGwtb3BhY2l0eT0iMC4wMzEzNyIgZmlsbD0iI2ZmZmZmZiIgc3Ryb2tlPSJub25lIiBzdHJva2Utd2lkdGg9IjAiIHN0cm9rZS1saW5lY2FwPSJidXR0Ii8+PHBhdGggZD0iTTI0NC4yNzExOCwxODEuNTg2MjhjLTAuMDg2MTksMS4xNDI3OCAtMS4wMzY0MywyLjAzMTU1IC0yLjE3NzI0LDIuMDA4MjRjLTAuMDA5MzYsLTAuMDAwMTkgLTAuMDE4NywtMC4wMDA0NCAtMC4wMjgwNSwtMC4wMDA3NWwtNC4xODg5NywwLjAwMDY5Yy0wLjAxNDQ3LDAuMDAwMDYgLTAuMDI4OTYsLTAuMDAwMDMgLTAuMDQzNDksLTAuMDAwMjdjLTEuMTgyMDgsLTAuMDE5MzYgLTIuMTI0OTEsLTEuMDA5NjYgLTIuMTA1ODksLTIuMjExOTJjMC4wMDAxNiwtMC4wMDk1MiAwLjAwMDM2LC0wLjAxOTAzIDAuMDAwNjMsLTAuMDI4NTNsMC4wMDA1MiwtMC4wNjk5M2wwLjAyNzA5LC0yLjM5MjZsMC4wMDI0NiwtMC4zMzQyM2MwLjAwMDE3LC0wLjAxNDcxIDAuMDAwNDksLTAuMDI5NDUgMC4wMDA5NiwtMC4wNDQyMmMwLjAzNzcxLC0xLjIwMTggMS4wMjYxOSwtMi4xNDQ5NiAyLjIwNzgzLC0yLjEwNjU5YzAuMDA5MzYsMC4wMDAzMSAwLjAxODcsMC4wMDA2NyAwLjAyODA1LDAuMDAxMDlsNC4wOTAzNywtMC4wMDE1MWMwLjAxNDQ3LC0wLjAwMDI0IDAuMDI4OTYsLTAuMDAwMzEgMC4wNDM0OSwtMC4wMDAyNmMxLjE4MjIxLDAuMDA1MTQgMi4xMzY1MSwwLjk4NDAzIDIuMTMxNDcsMi4xODY0MmMtMC4wMDAwMywwLjAwOTUzIC0wLjAwMDEzLDAuMDE5MDMgLTAuMDAwMzEsMC4wMjg1NGwwLjAwMDE5LDAuMDQzOXoiIGZpbGw9Im5vbmUiIHN0cm9rZT0iIzAwMDAwMCIgc3Ryb2tlLXdpZHRoPSIxLjUiIHN0cm9rZS1saW5lY2FwPSJidXR0Ii8+PHBhdGggZD0iTTIzOS4wMzU1MSwxNzcuMjE0N3Y1Ljk0MzY1IiBmaWxsPSJub25lIiBzdHJva2U9IiMwMDAwMDAiIHN0cm9rZS13aWR0aD0iMS4yIiBzdHJva2UtbGluZWNhcD0icm91bmQiLz48cGF0aCBkPSJNMjM2Ljg2OTU3LDE3OS44NTYzMmMwLC0wLjM0NTE4IDAuMjc5ODIsLTAuNjI1IDAuNjI1LC0wLjYyNWMwLjM0NTE4LDAgMC42MjUsMC4yNzk4MiAwLjYyNSwwLjYyNWMwLDAuMzQ1MTggLTAuMjc5ODIsMC42MjUgLTAuNjI1LDAuNjI1Yy0wLjM0NTE4LDAgLTAuNjI1LC0wLjI3OTgyIC0wLjYyNSwtMC42MjV6IiBmaWxsPSIjMDAwMDAwIiBzdHJva2U9Im5vbmUiIHN0cm9rZS13aWR0aD0iMC41IiBzdHJva2UtbGluZWNhcD0iYnV0dCIvPjxwYXRoIGQ9Ik0yMzYuODUzNjMsMTc4LjQzNDA0YzAsLTAuMzQ1MTggMC4yNzk4MiwtMC42MjUgMC42MjUsLTAuNjI1YzAuMzQ1MTgsMCAwLjYyNSwwLjI3OTgyIDAuNjI1LDAuNjI1YzAsMC4zNDUxOCAtMC4yNzk4MiwwLjYyNSAtMC42MjUsMC42MjVjLTAuMzQ1MTgsMCAtMC42MjUsLTAuMjc5ODIgLTAuNjI1LC0wLjYyNXoiIGZpbGw9IiMwMDAwMDAiIHN0cm9rZT0ibm9uZSIgc3Ryb2tlLXdpZHRoPSIwLjUiIHN0cm9rZS1saW5lY2FwPSJidXR0Ii8+PHBhdGggZD0iTTIzNi44Mzc2OSwxODEuMjc3NjZjMCwtMC4zNDUxOCAwLjI3OTgyLC0wLjYyNSAwLjYyNSwtMC42MjVjMC4zNDUxOCwwIDAuNjI1LDAuMjc5ODIgMC42MjUsMC42MjVjMCwwLjM0NTE4IC0wLjI3OTgyLDAuNjI1IC0wLjYyNSwwLjYyNWMtMC4zNDUxOCwwIC0wLjYyNSwtMC4yNzk4MiAtMC42MjUsLTAuNjI1eiIgZmlsbD0iIzAwMDAwMCIgc3Ryb2tlPSJub25lIiBzdHJva2Utd2lkdGg9IjAuNSIgc3Ryb2tlLWxpbmVjYXA9ImJ1dHQiLz48L2c+PC9nPjwvc3ZnPg==',
        zoomIn:   'data:image/svg+xml;base64,PHN2ZyB2ZXJzaW9uPSIxLjEiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgeG1sbnM6eGxpbms9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkveGxpbmsiIHdpZHRoPSIxMy4yNSIgaGVpZ2h0PSIxMy4yNSIgdmlld0JveD0iMCwwLDEzLjI1LDEzLjI1Ij48ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSgtMjMzLjM3NSwtMTczLjM3NSkiPjxnIHN0cm9rZS1taXRlcmxpbWl0PSIxMCI+PHBhdGggZD0iTTIzMy4zNzUsMTgwYzAsLTMuNjU4ODkgMi45NjYxMSwtNi42MjUgNi42MjUsLTYuNjI1YzMuNjU4ODksMCA2LjYyNSwyLjk2NjExIDYuNjI1LDYuNjI1YzAsMy42NTg4OSAtMi45NjYxMSw2LjYyNSAtNi42MjUsNi42MjVjLTMuNjU4ODksMCAtNi42MjUsLTIuOTY2MTEgLTYuNjI1LC02LjYyNXoiIGZpbGwtb3BhY2l0eT0iMC4wMzEzNyIgZmlsbD0iI2ZmZmZmZiIgc3Ryb2tlPSJub25lIiBzdHJva2Utd2lkdGg9IjAiIHN0cm9rZS1saW5lY2FwPSJidXR0Ii8+PGcgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMDAwMDAwIiBzdHJva2Utd2lkdGg9IjEuNSI+PHBhdGggZD0iTTIzNC43ODI3NiwxNzkuMDYyNjVjMCwtMi4wNTMxMyAxLjY2NDM5LC0zLjcxNzUzIDMuNzE3NTMsLTMuNzE3NTNjMi4wNTMxMywwIDMuNzE3NTMsMS42NjQ0IDMuNzE3NTMsMy43MTc1M2MwLDIuMDUzMTMgLTEuNjY0NCwzLjcxNzUzIC0zLjcxNzUzLDMuNzE3NTNjLTIuMDUzMTMsMCAtMy43MTc1MywtMS42NjQzOSAtMy43MTc1MywtMy43MTc1M3oiIHN0cm9rZS1saW5lY2FwPSJidXR0Ii8+PHBhdGggZD0iTTI0My45NjcyNCwxODMuNjU0ODlsLTIuMDQwOTksLTIuMTg2NzgiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIvPjwvZz48cGF0aCBkPSJNMjM3LjA4MDk3LDE3OS4xMDY4M2gzLjAxNzI0IiBmaWxsPSJub25lIiBzdHJva2U9IiMwMDAwMDAiIHN0cm9rZS13aWR0aD0iMS41IiBzdHJva2UtbGluZWNhcD0icm91bmQiLz48cGF0aCBkPSJNMjM4LjU4OTU5LDE3Ny41OTgyMXYzLjEyNSIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMDAwMDAwIiBzdHJva2Utd2lkdGg9IjEuNSIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIi8+PC9nPjwvZz48L3N2Zz4=',
        zoomOut:  'data:image/svg+xml;base64,PHN2ZyB2ZXJzaW9uPSIxLjEiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgeG1sbnM6eGxpbms9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkveGxpbmsiIHdpZHRoPSIxMy4yNSIgaGVpZ2h0PSIxMy4yNSIgdmlld0JveD0iMCwwLDEzLjI1LDEzLjI1Ij48ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSgtMjMzLjM3NSwtMTczLjM3NSkiPjxnIHN0cm9rZS1taXRlcmxpbWl0PSIxMCI+PHBhdGggZD0iTTIzMy4zNzUsMTgwYzAsLTMuNjU4ODkgMi45NjYxMSwtNi42MjUgNi42MjUsLTYuNjI1YzMuNjU4ODksMCA2LjYyNSwyLjk2NjExIDYuNjI1LDYuNjI1YzAsMy42NTg4OSAtMi45NjYxMSw2LjYyNSAtNi42MjUsNi42MjVjLTMuNjU4ODksMCAtNi42MjUsLTIuOTY2MTEgLTYuNjI1LC02LjYyNXoiIGZpbGwtb3BhY2l0eT0iMC4wMzEzNyIgZmlsbD0iI2ZmZmZmZiIgc3Ryb2tlPSJub25lIiBzdHJva2Utd2lkdGg9IjAiIHN0cm9rZS1saW5lY2FwPSJidXR0Ii8+PGcgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMDAwMDAwIiBzdHJva2Utd2lkdGg9IjEuNSI+PHBhdGggZD0iTTIzNC43ODI3NiwxNzkuMDYyNjVjMCwtMi4wNTMxMyAxLjY2NDM5LC0zLjcxNzUzIDMuNzE3NTMsLTMuNzE3NTNjMi4wNTMxMywwIDMuNzE3NTMsMS42NjQ0IDMuNzE3NTMsMy43MTc1M2MwLDIuMDUzMTMgLTEuNjY0NCwzLjcxNzUzIC0zLjcxNzUzLDMuNzE3NTNjLTIuMDUzMTMsMCAtMy43MTc1MywtMS42NjQzOSAtMy43MTc1MywtMy43MTc1M3oiIHN0cm9rZS1saW5lY2FwPSJidXR0Ii8+PHBhdGggZD0iTTI0My45NjcyNCwxODMuNjU0ODlsLTIuMDQwOTksLTIuMTg2NzgiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIvPjwvZz48cGF0aCBkPSJNMjM3LjA4MDk3LDE3OS4xMDY4M2gzLjAxNzI0IiBmaWxsPSJub25lIiBzdHJva2U9IiMwMDAwMDAiIHN0cm9rZS13aWR0aD0iMS41IiBzdHJva2UtbGluZWNhcD0icm91bmQiLz48L2c+PC9nPjwvc3ZnPg==',
        info:     'data:image/svg+xml;base64,PHN2ZyB2ZXJzaW9uPSIxLjEiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgeG1sbnM6eGxpbms9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkveGxpbmsiIHdpZHRoPSIxMy4yNSIgaGVpZ2h0PSIxMy4yNSIgdmlld0JveD0iMCwwLDEzLjI1LDEzLjI1Ij48ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSgtMjMzLjM3NSwtMTczLjM3NSkiPjxnIHN0cm9rZS1taXRlcmxpbWl0PSIxMCI+PHBhdGggZD0iTTIzMy4zNzUsMTgwYzAsLTMuNjU4ODggMi45NjYxMiwtNi42MjUgNi42MjUsLTYuNjI1YzMuNjU4ODgsMCA2LjYyNSwyLjk2NjEyIDYuNjI1LDYuNjI1YzAsMy42NTg4OCAtMi45NjYxMiw2LjYyNSAtNi42MjUsNi42MjVjLTMuNjU4ODgsMCAtNi42MjUsLTIuOTY2MTIgLTYuNjI1LC02LjYyNXoiIGZpbGwtb3BhY2l0eT0iMC4wMzEzNyIgZmlsbD0iI2ZmZmZmZiIgc3Ryb2tlPSJub25lIiBzdHJva2Utd2lkdGg9IjAiIHN0cm9rZS1saW5lY2FwPSJidXR0Ii8+PHBhdGggZD0iTTIzNS45Njk5NywxODBjMCwtMi4yMjU3MiAxLjgwNDMsLTQuMDMwMDMgNC4wMzAwMywtNC4wMzAwM2MyLjIyNTcyLDAgNC4wMzAwMywxLjgwNDMxIDQuMDMwMDMsNC4wMzAwM2MwLDIuMjI1NzIgLTEuODA0MzEsNC4wMzAwMyAtNC4wMzAwMyw0LjAzMDAzYy0yLjIyNTcyLDAgLTQuMDMwMDMsLTEuODA0MyAtNC4wMzAwMywtNC4wMzAwM3oiIGZpbGw9Im5vbmUiIHN0cm9rZT0iIzAwMDAwMCIgc3Ryb2tlLXdpZHRoPSIxLjUiIHN0cm9rZS1saW5lY2FwPSJidXR0Ii8+PHBhdGggZD0iTTI0MC4wMTMxNCwxODIuMDA5MDdsMC4wMzM0NiwtMS45OTM4OSIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMDAwMDAwIiBzdHJva2Utd2lkdGg9IjEuNSIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIi8+PHBhdGggZD0iTTIzOS4xODIyNywxNzguMTMxOTNjMCwtMC40NjYwNSAwLjM3NzgsLTAuODQzODUgMC44NDM4NSwtMC44NDM4NWMwLjQ2NjA1LDAgMC44NDM4NSwwLjM3NzggMC44NDM4NSwwLjg0Mzg1YzAsMC40NjYwNSAtMC4zNzc4LDAuODQzODUgLTAuODQzODUsMC44NDM4NWMtMC40NjYwNSwwIC0wLjg0Mzg1LC0wLjM3NzggLTAuODQzODUsLTAuODQzODV6IiBmaWxsPSIjMDAwMDAwIiBzdHJva2U9Im5vbmUiIHN0cm9rZS13aWR0aD0iMCIgc3Ryb2tlLWxpbmVjYXA9ImJ1dHQiLz48L2c+PC9nPjwvc3ZnPg==',
        download: 'data:image/svg+xml;base64,PHN2ZyB2ZXJzaW9uPSIxLjEiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgeG1sbnM6eGxpbms9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkveGxpbmsiIHdpZHRoPSIxMy4yNSIgaGVpZ2h0PSIxMy4yNSIgdmlld0JveD0iMCwwLDEzLjI1LDEzLjI1Ij48ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSgtMjMzLjM3NSwtMTczLjM3NSkiPjxnIHN0cm9rZS1taXRlcmxpbWl0PSIxMCI+PHBhdGggZD0iTTIzMy4zNzUsMTgwYzAsLTMuNjU4ODggMi45NjYxMiwtNi42MjUgNi42MjUsLTYuNjI1YzMuNjU4ODgsMCA2LjYyNSwyLjk2NjEyIDYuNjI1LDYuNjI1YzAsMy42NTg4OCAtMi45NjYxMiw2LjYyNSAtNi42MjUsNi42MjVjLTMuNjU4ODgsMCAtNi42MjUsLTIuOTY2MTIgLTYuNjI1LC02LjYyNXoiIGZpbGwtb3BhY2l0eT0iMC4wMzEzNyIgZmlsbD0iI2ZmZmZmZiIgc3Ryb2tlPSJub25lIiBzdHJva2Utd2lkdGg9IjAiIHN0cm9rZS1saW5lY2FwPSJidXR0Ii8+PHBhdGggZD0iTTIzNS45Njk5NywxODBjMCwtMi4yMjU3MiAxLjgwNDMsLTQuMDMwMDMgNC4wMzAwMywtNC4wMzAwM2MyLjIyNTcyLDAgNC4wMzAwMywxLjgwNDMxIDQuMDMwMDMsNC4wMzAwM2MwLDIuMjI1NzIgLTEuODA0MzEsNC4wMzAwMyAtNC4wMzAwMyw0LjAzMDAzYy0yLjIyNTcyLDAgLTQuMDMwMDMsLTEuODA0MyAtNC4wMzAwMywtNC4wMzAwM3oiIGZpbGw9Im5vbmUiIHN0cm9rZT0iIzAwMDAwMCIgc3Ryb2tlLXdpZHRoPSIxLjUiIHN0cm9rZS1saW5lY2FwPSJidXR0Ii8+PHBhdGggZD0iTTIzOS45Mzk3NiwxODAuNjg4MjZsMC4wMzM0NiwtMS45OTM4OSIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMDAwMDAwIiBzdHJva2Utd2lkdGg9IjEuNSIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIi8+PHBhdGggZD0iTTIzOC42Njg2MiwxODAuMzY5OTdsMS4xMDA2OCwxLjMyMDgxIiBmaWxsPSJub25lIiBzdHJva2U9IiMwMDAwMDAiIHN0cm9rZS13aWR0aD0iMS41IiBzdHJva2UtbGluZWNhcD0icm91bmQiLz48cGF0aCBkPSJNMjQwLjEzNjE5LDE4MS42OTA3OGwxLjE3MDUsLTEuMzIwODEiIGZpbGw9Im5vbmUiIHN0cm9rZT0iIzAwMDAwMCIgc3Ryb2tlLXdpZHRoPSIxLjUiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIvPjwvZz48L2c+PC9zdmc+',
        search: 'data:image/svg+xml;base64,PHN2ZyB2ZXJzaW9uPSIxLjEiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgeG1sbnM6eGxpbms9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkveGxpbmsiIHdpZHRoPSIzMy43NzE4MiIgaGVpZ2h0PSIzMy43NzE4MiIgdmlld0JveD0iMCwwLDMzLjc3MTgyLDMzLjc3MTgyIj48ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSgtMjIzLjExNDA5LC0xNjMuMTE0MDkpIj48ZyBzdHJva2UtbWl0ZXJsaW1pdD0iMTAiPjxwYXRoIGQ9Ik0yMjMuMTE0MDksMTk2Ljg4NTkxdi0zMy43NzE4MmgzMy43NzE4MnYzMy43NzE4MnoiIGZpbGwtb3BhY2l0eT0iMC4wMDc4NCIgZmlsbD0iI2ZmZmZmZiIgc3Ryb2tlPSJub25lIiBzdHJva2Utd2lkdGg9Im5vbmUiIHN0cm9rZS1saW5lY2FwPSJidXR0Ii8+PHBhdGggZD0iTTIyOC42NDgxNiwxNzYuNDI2MTJjMCwtNC42MTk2NyAzLjc0NDk4LC04LjM2NDY1IDguMzY0NjUsLTguMzY0NjVjNC42MTk2NywwIDguMzY0NjUsMy43NDQ5OCA4LjM2NDY1LDguMzY0NjVjMCw0LjYxOTY3IC0zLjc0NDk4LDguMzY0NjUgLTguMzY0NjUsOC4zNjQ2NWMtNC42MTk2NywwIC04LjM2NDY1LC0zLjc0NDk4IC04LjM2NDY1LC04LjM2NDY1eiIgZmlsbD0ibm9uZSIgc3Ryb2tlPSIjMDAwMDAwIiBzdHJva2Utd2lkdGg9IjMiIHN0cm9rZS1saW5lY2FwPSJidXR0Ii8+PHBhdGggZD0iTTI0My45NTcwNiwxODIuNDIzNDJsNi43ODY0Miw2LjE1NTEyIiBmaWxsPSJub25lIiBzdHJva2U9IiMwMDAwMDAiIHN0cm9rZS13aWR0aD0iMyIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIi8+PC9nPjwvZz48L3N2Zz48IS0tcm90YXRpb25DZW50ZXI6MTYuODg1OTA4NDEzMjMxNTMzOjE2Ljg4NTkwODQxMzIzMTUzMy0tPg==',
        pen:      'data:image/svg+xml;base64,PHN2ZyB2ZXJzaW9uPSIxLjEiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgeG1sbnM6eGxpbms9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkveGxpbmsiIHdpZHRoPSI3MC40NDcyMSIgaGVpZ2h0PSI3MC40NDcyMSIgdmlld0JveD0iMCwwLDcwLjQ0NzIxLDcwLjQ0NzIxIj48ZyB0cmFuc2Zvcm09InRyYW5zbGF0ZSgtMjA0Ljc3NjM5LC0xNDQuNzc2MzkpIj48ZyBzdHJva2UtbWl0ZXJsaW1pdD0iMTAiPjxwYXRoIGQ9Ik0yMTEuODc0OTIsMjAyLjM5NzRjLTEuMDI5NjcsLTAuMDE0MDQgLTEuODYwOTcsLTAuODQ1MzQgLTEuODc1LC0xLjg3NWMwLjA2OTk1LC0wLjQyODYzIDAuMTc3OCwtMC44NTAyIDAuMzIyMjYsLTEuMjU5NzZjMC4yMTQ4NSwtMC43MDMxNCAwLjQ4MzQsLTEuNTUyNzUgMC44MDU2NywtMi41NDg4M2MwLjMyMjI3LC0wLjk5NjA4IDAuNjczODMsLTIuMDY1NDIgMS4wNTQ2OSwtMy4yMDhjMC4zODA4NiwtMS4xNDI1OCAwLjc0NzA3LC0yLjIzNjMzIDEuMDk4NjMsLTMuMjgxMjVjMC4zNTE1NiwtMS4wNDQ0MiAwLjY2NDA2LC0xLjk2MjQgMC45Mzc1LC0yLjc1MzljMC4yNzM0NCwtMC43OTEwMiAwLjQ1ODk5LC0xLjMyMzI0IDAuNTU2NjQsLTEuNTk2NjhjMC4wOTM5NSwtMC4yNzg4MyAwLjI1NDkxLC0wLjUzMDMzIDAuNDY4NzUsLTAuNzMyNDNsMzIuMzQzNzUsLTMyLjM0Mzc1YzAuODUwMzksLTAuODUzMzUgMS44NjA5NCwtMS41MzAzNiAyLjk3MzYzLC0xLjk5MjE4YzEuMTA4MzQsLTAuNDY1OCAyLjI5ODc1LC0wLjcwNDg4IDMuNTAxLC0wLjcwMzEzYzEuMjE4MzcsLTAuMDA2NDIgMi40MjUwMiwwLjIzNzkgMy41NDQ5MiwwLjcxNzc4YzIuMjA4OTMsMC45MzkzOSAzLjk2Nzg0LDIuNjk4MjkgNC45MDcyMyw0LjkwNzIyYzAuOTUxOTIsMi4yNTExNSAwLjk1NzIsNC43OTA4MSAwLjAxNDY1LDcuMDQ1OWMtMC40NzE0MywxLjEwNzUyIC0xLjE0NzI4LDIuMTE2MzMgLTEuOTkyMTksMi45NzM2M2wtNC43NDYwOSw0Ljc3NTM5YzAuNzE2MDMsMC43Njg0NyAxLjMzMTMyLDEuNjI0OTcgMS44MzEwNSwyLjU0ODgzYzAuNDY1NiwwLjk1Njg4IDAuNjkxODEsMi4wMTI1MyAwLjY1OTE4LDMuMDc2MTdjMC4wMDAzLDEuOTg5MTMgLTAuNzkwMTcsMy44OTY3OSAtMi4xOTcyNyw1LjMwMjc0bC01LjM5MDYyLDUuMzkwNjJjLTAuNDY5NzYsMC40NzcxOCAtMS4xNTkzMSwwLjY2NTgzIC0xLjgwNjU2LDAuNDk0MjFjLTAuNjQ3MjQsLTAuMTcxNjIgLTEuMTUyNzYsLTAuNjc3MTMgLTEuMzI0MzcsLTEuMzI0MzdjLTAuMTcxNjEsLTAuNjQ3MjQgMC4wMTcwMiwtMS4zMzY4IDAuNDk0MjEsLTEuODA2NTZsNS4zOTA2MiwtNS4zOTA2MmMwLjcyMzM0LC0wLjY5Njc5IDEuMTI2MjgsLTEuNjYxNzIgMS4xMTMyOSwtMi42NjZjMC4wMDgzMywtMC41Njk3IC0wLjEyMjQsLTEuMTMyODUgLTAuMzgwODYsLTEuNjQwNjJjLTAuMjY1MjYsLTAuNTAyMDUgLTAuNjIzMTEsLTAuOTQ5MzcgLTEuMDU0NjksLTEuMzE4MzZsLTI0LjkzMTY0LDI0LjkwMjM0Yy0wLjIzMTc5LDAuMjQxMjggLTAuNTI1ODUsMC40MTM2NiAtMC44NDk2MSwwLjQ5ODA1bC0xNSwzLjc1Yy0wLjE1NDA0LDAuMDM0MzkgLTAuMzExMDEsMC4wNTQgLTAuNDY4NzcsMC4wNTg1NnpNMjE0LjU3MDIzLDIwNS42NDk0bDUuMDM5MDYsLTEuMjU5NzdjMS4xMjQ5NSwwLjU2Mzc1IDIuMzA4OTQsMS4wMDA5OSAzLjUzMDI4LDEuMzAzNzFjMS4yMjE5NCwwLjMwMzEzIDIuNDc2MzcsMC40NTU2MyAzLjczNTM1LDAuNDU0MWMxLjM0NDQzLC0wLjAwMzI2IDIuNjcyNzMsLTAuMjkyOSAzLjg5NjQ4LC0wLjg0OTYxYzEuMzA5MTcsLTAuNTg4ODkgMi41NTk4NCwtMS4zMDAwNSAzLjczNTM2LC0yLjEyNGMxLjIyMDcsLTAuODQ5NjEgMi40MjE4NywtMS43Njc1OCAzLjYwMzUxLC0yLjc1MzkxYzEuMTgxNjQsLTAuOTg1ODQgMi4zNDM3NSwtMS45MDM4IDMuNDg2MzMsLTIuNzUzOWMxLjA2Mjg2LC0wLjc5OTI1IDIuMTg5NzEsLTEuNTA5NjYgMy4zNjkxNCwtMi4xMjRjMS4wMDQ5NCwtMC41NDExNyAyLjEyNTM0LC0wLjgzMjU3IDMuMjY2NiwtMC44NDk2MWMwLjU4OTAyLC0wLjAwNTkyIDEuMTc0MzYsMC4wOTMzIDEuNzI4NTIsMC4yOTNjMC43NDM1OCwwLjI0ODU3IDEuNDMwNjEsMC42NDE4NyAyLjAyMTQ4LDEuMTU3MjNjMC41MTgxOSwwLjQ2NzU3IDAuOTYyNjcsMS4wMTA4MiAxLjMxODM2LDEuNjExMzNjMC4zNjE3NywwLjYxODE1IDAuNjYxMDksMS4yNzA3OCAwLjg5MzU2LDEuOTQ4MjRjMC4yNDQxNCwwLjcwMzEzIDAuNDgzNCwxLjQyNTc5IDAuNzE3NzcsMi4xNjhjMC4wOTg2MSwwLjMzNDg4IDAuMjMxMTQsMC42NTg4MiAwLjM5NTUxLDAuOTY2OGMwLjE2MjY0LDAuMzA3OTcgMC4zNjQ1MSwwLjU5MzU1IDAuNjAwNTgsMC44NDk2MWMwLjEyNzQzLDAuMTQ2MjkgMC4yNjk4LDAuMjc4ODQgMC40MjQ4MSwwLjM5NTVjMC4xNTM5MSwwLjEyMjk3IDAuMzQ0OTksMC4xOTAxMSAwLjU0MiwwLjE5MDQzYzAuNTM0MjksLTAuMDI1NjMgMS4wNTc3LC0wLjE2MDIyIDEuNTM4MDksLTAuMzk1NWMwLjYyMTA0LC0wLjI3NzA1IDEuMjIyOTYsLTAuNTk1MTQgMS44MDE3NSwtMC45NTIxNWMwLjYwNTQ2LC0wLjM3MDYxIDEuMTg2NTMsLTAuNzUxNDYgMS43NDMxNywtMS4xNDI1OGMwLjU1NjY3LC0wLjM5MDYyIDEuMDIwNTMsLTAuNzEyOSAxLjM5MTYsLTAuOTY2OGMwLjU5ODI4LC0wLjM5NzU4IDEuMjE5NDcsLTAuNzU5NTQgMS44NjAzNSwtMS4wODRjMC42NTE2OSwtMC4zMzA4OSAxLjMyMTczLC0wLjYyNDM0IDIuMDA2ODQsLTAuODc4OTFjMC4yODY2LC0wLjEyNjUyIDAuNTk1MDUsLTAuMTk2MTcgMC45MDgyLC0wLjIwNTA4YzAuNDk5MjUsLTAuMDA2NTIgMC45Nzk5NiwwLjE4ODkzIDEuMzMzMDEsMC41NDE5OWMwLjM1MzA1LDAuMzUzMDYgMC41NDg1LDAuODMzNzYgMC41NDE5OSwxLjMzMzAxYzAuMDAyMywwLjQwMzQ0IC0wLjEzMTkzLDAuNzk1OCAtMC4zODA4NiwxLjExMzI5Yy0wLjI0MDkzLDAuMzIzMjQgLTAuNTgwMTUsMC41NTk2NiAtMC45NjY4LDAuNjczODJjLTAuMDE5NTMsMC4wMzk1NSAtMC4wNzgxMiwwLjA1ODYgLTAuMTc1NzgsMC4wNTg2Yy0wLjk4NTY2LDAuNDA3NDggLTEuOTI3ODksMC45MTI5NSAtMi44MTI1LDEuNTA4NzljLTAuOTU3MDIsMC42MzQ3NiAtMS45MjM4MywxLjI1OTc2IC0yLjk0NDMzLDEuNTk2NjhjLTAuOTIxMjIsMC40MzQ3MiAtMS45MjU3NCwwLjY2NDYgLTIuOTQ0MzQsMC42NzM4MmMtMC43MjM5NywwLjAwOTM3IC0xLjQzODg1LC0wLjE2MTc5IC0yLjA4MDA4LC0wLjQ5OGMtMC42NDE3NiwtMC4zNDUwMiAtMS4yMTcxMSwtMC44MDEzNCAtMS42OTkyMiwtMS4zNDc2NmMtMC40MjYyLC0wLjQ1NTA5IC0wLjc4NjE3LC0wLjk2Nzk0IC0xLjA2OTMzLC0xLjUyMzQ0Yy0wLjI3NTUzLC0wLjU1Njc1IC0wLjUwNTc3LC0xLjEzNDc5IC0wLjY4ODQ4LC0xLjcyODUxYy0wLjExNzE5LC0wLjM1MTU2IC0wLjI1MzkxLC0wLjc4MTI1IC0wLjQxMDE2LC0xLjI4OTA2Yy0wLjE1NTMsLTAuNTA1NSAtMC4zNTYzMywtMC45OTU4MSAtMC42MDA1OCwtMS40NjQ4NWMtMC4yMjY3NywtMC40NDQ4NiAtMC41MjM1MiwtMC44NTA0MSAtMC44Nzg5MSwtMS4yMDExN2MtMC4zMjEyNCwtMC4zMjM2IC0wLjc1OTg4LC0wLjUwMzI2IC0xLjIxNTgyLC0wLjQ5OGMtMC44ODM4LDAuMDQ2NTcgLTEuNzM2NjUsMC4zNDEgLTIuNDYwOTQsMC44NDk2MWMtMS4wMTM5MSwwLjY0OTc1IC0xLjk5MTg5LDEuMzUzOTEgLTIuOTI5NjgsMi4xMDkzOGMtMS4wNTQ2NiwwLjgzOTg0IC0yLjE4NzQ4LDEuNzU3ODEgLTMuMzk4NDQsMi43NTM5Yy0xLjIxNDI1LDAuOTk4NzMgLTIuNDkxMjksMS45MTg1OCAtMy44MjMyNCwyLjc1MzkxYy0xLjMzMDU2LDAuODM2MTYgLTIuNzM4NCwxLjU0MjU0IC00LjIwNDEsMi4xMDkzN2MtMS40NDc1OCwwLjU2MzQyIC0yLjk4NzY0LDAuODUxNTYgLTQuNTQxLDAuODQ5NjFjLTIuMTczNDEsLTAuMDAwNjUgLTQuMzMxNjQsLTAuMzYyMDEgLTYuMzg2NzIsLTEuMDY5MzNjLTIuMDYzMiwtMC42OTg4MSAtNC4wMDE2NCwtMS43MjI0MyAtNS43NDIxOSwtMy4wMzIyM3pNMjE0Ljc0NjAxLDE5Ny44ODU3M2wxMS4xNjIxMSwtMi44MTI1bDMxLjk5MjE5LC0zMS45NjI5YzAuNTAzOSwtMC41MDE5NSAwLjkwMjM0LC0xLjA5OTYxIDEuMTcxODcsLTEuNzU3ODFjMC4yNzI2LC0wLjY1OTUxIDAuNDExOTksLTEuMzY2NDUgMC40MTAxNiwtMi4wODAwOGMwLjAwNjM5LC0wLjcyOTcyIC0wLjEzODI0LC0xLjQ1Mjg3IC0wLjQyNDgsLTIuMTI0Yy0wLjU0OTk2LC0xLjI5MjE1IC0xLjU3ODk1LC0yLjMyMTEzIC0yLjg3MTEsLTIuODcxMDljLTAuNjcxMTgsLTAuMjg2MzggLTEuMzk0MywtMC40MzEwMSAtMi4xMjQsLTAuNDI0ODFjLTAuNzEzNjIsLTAuMDAxNzggLTEuNDIwNTUsMC4xMzc2MiAtMi4wODAwOCwwLjQxMDE2Yy0wLjY1ODEsMC4yNjk3MSAtMS4yNTU3MywwLjY2ODEyIC0xLjc1NzgxLDEuMTcxODdsLTMyLjAyMTQ5LDMyLjA1MDcyeiIgZmlsbD0iIzAwMDAwMCIgc3Ryb2tlPSIjMDAwMDAwIiBzdHJva2Utd2lkdGg9IjIiLz48cGF0aCBkPSJNMjA0Ljc3NjQsMjE1LjIyMzYxdi03MC40NDcyMWg3MC40NDcyMXY3MC40NDcyMXoiIGZpbGwtb3BhY2l0eT0iMC4wMjM1MyIgZmlsbD0iI2ZmZmZmZiIgc3Ryb2tlPSJub25lIiBzdHJva2Utd2lkdGg9IjAiLz48L2c+PC9nPjwvc3ZnPjwhLS1yb3RhdGlvbkNlbnRlcjozNS4yMjM2MDQ5OTk5OTk5OTozNS4yMjM2MDQ5OTk5OTk5OS0tPg=='
    };

    // ================= [批注状态与配置区] =================
    let state = {
        active: false,
        stylusMode: false,
        tool: 'brush', // 'brush' or 'eraser'
        color: '#ff0000',
        thickness: 4,
        opacity: 1.0,
        strokes: [],
        currentStroke: null
    };
    const colors = ['#000000','#ffffff','#888888','#ff0000','#ffa500','#ffff00','#00ff00','#00ffff','#0000ff','#800080','#ffc0cb'];
    const MAX_Z = 2147483647;

    // ================= [样式注入] =================
    GM_addStyle(`
        #toolbarContainer, #secondaryToolbar { display: none !important; }
        #viewerContainer { top: 0 !important; height: 100% !important; overflow: auto !important; }
        
        /* [修复] 动态禁用原生触摸行为，强制使用JS接管 */
        .disable-native-touch { touch-action: none !important; }

         #sidebarContainer {
            z-index: ${MAX_Z} !important;
            top: 5px !important; height: calc(100% - 10px) !important; border-radius: 16px !important;
            background: linear-gradient(45deg, rgba(216, 253, 236, 0.3) 0%, rgba(183, 204, 250, 0.35) 100%) !important;
            backdrop-filter: blur(12px) saturate(180%) !important; -webkit-backdrop-filter: blur(12px) saturate(180%) !important;
            box-shadow: 5px 0 20px rgba(58, 58, 58, 0.08) !important; border: none !important; overflow: hidden !important;
            transition: left 0.3s ease, transform 0.3s ease !important;
        }
        html[dir='ltr'] #outerContainer.sidebarOpen #sidebarContainer, #outerContainer.sidebarOpen #sidebarContainer { left: 5px !important; }
        #toolbarSidebar, #sidebarContent { background: transparent !important; }
        #toolbarSidebar { border-radius: 16px 16px 0 0 !important; }
        #sidebarContent { border-radius: 0 0 16px 16px !important; }
        #sidebarContent button, #sidebarContent a, .thumbnailImage, .thumbnailSelectionRing, #toolbarSidebar button, #toolbarSidebar input { border-radius: 12px !important; }
        .pdfViewer .page { border-radius: 16px !important; overflow: hidden !important; margin: 25px auto !important; box-shadow: 0 4px 18px rgba(0,0,0,0.06) !important; border: none !important; }
        .findbar{ left:155px!important }

        /* ======== 悬浮UI通用毛玻璃样式 ======== */
        .glass-ui {
            background: rgba(245, 247, 250, 0.75) !important; color: #222;
            backdrop-filter: blur(15px) saturate(180%); -webkit-backdrop-filter: blur(15px) saturate(180%);
            border: 1.5px solid rgba(60, 60, 60, 0.17); box-shadow: 0 3px 10px rgba(53, 52, 52, 0.08);
            z-index: ${MAX_Z}; user-select: none !important; -webkit-user-select: none !important;
            --base-tx: 0px; --rub-tx: 0px; --rub-ty: 0px; --rub-sx: 1; --rub-sy: 1;
            transform: translateX(var(--base-tx)) translate(var(--rub-tx), var(--rub-ty)) scale(var(--rub-sx), var(--rub-sy));
            transition: transform 0.4s cubic-bezier(0.18, 0.89, 0.32, 1.28), background 0.4s ease, border-color 0.4s ease, color 0.4s ease;
            position: relative;
        }
        .glass-ui.rubbing { transition: transform 0.1s ease-out, background 0.4s, color 0.4s !important; }
        .glass-ui::before { content: ''; position: absolute; top: var(--my, -100px); left: var(--mx, -100px); width: 160px; height: 160px; transform: translate(-50%, -50%); background: radial-gradient(circle at center, rgba(0,0,0,0.2) 0%, rgba(0,0,0,0) 70%); pointer-events: none; z-index: 0; opacity: 0; transition: opacity 0.2s; }
        .glass-ui.rubbing::before { opacity: 1; }
        .glass-ui.dark-theme::before { background: radial-gradient(circle at center, rgba(255,255,255,0.2) 0%, rgba(255,255,255,0) 70%); }
        .glass-ui.dark-theme { background: rgba(0, 0, 0, 0.8) !important; border-color: rgba(255, 255, 255, 0.15) !important; color: #ffffff !important; box-shadow: 0 5px 15px rgba(0, 0, 0, 0.5); }
        .glass-ui.dark-theme button { color: #ffffff !important; }
        .glass-ui.dark-theme .pill-icon-custom { background-color: transparent !important; background-image: linear-gradient(0deg, #ffffff, #ffffff) !important; }

        /* 侧边药丸及工具栏 */
        .custom-pill { position: fixed; height: 40px; border-radius: 30px !important; display: flex; align-items: center; justify-content: space-around; top: 20px; overflow: hidden;  touch-action: none !important; }
        #outerContainer.sidebarOpen .left-pill { --base-tx: 205px; }
        .custom-pill button { background: none !important; border: none; cursor: pointer; width: 34px; height: 34px; display: flex; align-items: center; justify-content: center; border-radius: 50%; color: inherit; opacity: 0.8; outline: none !important; transition: opacity 0.2s, color 0.4s; -webkit-tap-highlight-color: transparent !important; position: relative; z-index: 1;pointer-events: auto !important;    transition: transform 0.2s ease, opacity 0.2s ease;}
        .custom-pill button:hover { opacity: 1; }
        .custom-pill button.active-pen { color: #2196f3 !important; opacity: 1; }
        .pill-icon-custom { width: 24px; height: 24px; background-color: currentColor; -webkit-mask-size: contain; mask-size: contain; -webkit-mask-repeat: no-repeat; mask-repeat: no-repeat; -webkit-mask-position: center; mask-position: center; }

        /* ---------------- [重构：全新批注工具栏区] ---------------- */
        #ann-toolbar {
            position: fixed; top: 20px; left: 50%; transform: translateX(-50%) !important;
            padding: 12px 20px; border-radius: 16px; display: none; flex-direction: column; gap: 14px;
            font-family: sans-serif; box-sizing: border-box; width: fit-content; max-width: 95vw;
            --rub-tx: 0px !important; --rub-ty: 0px !important; --rub-sx: 1 !important; --rub-sy: 1 !important;
        }
        #ann-toolbar::before { display: none !important; }

        .ann-row { display: flex; align-items: center; width: 100%; gap: 12px; }
        
        /* 颜色列表 */
        .color-list { display: flex; gap: 8px; overflow-x: auto; scrollbar-width: none; padding-right: 10px; }
        .color-list::-webkit-scrollbar { display: none; }
        .ann-dot { width: 27px; height: 27px; border-radius: 50%; cursor: pointer; border: 3px solid transparent; flex-shrink: 0; transition: 0.2s; box-shadow: inset 0 0 0 1px rgba(0,0,0,0.1); }
        .ann-dot.active { border-color: #222; transform: scale(0.97); box-shadow: 0 2px 6px rgba(0,0,0,0.3); }
        .glass-ui.dark-theme .ann-dot.active { border-color: #fff; }

        /* 按钮样式 */
        .icon-btn { width: 32px; height: 32px; border-radius: 50%; border: none; cursor: pointer; display: flex; justify-content: center; align-items: center; background: #3b82f6; color: white; transition: 0.2s; flex-shrink:0; }
        .icon-btn.active { background: #2563eb; box-shadow: inset 0 0 0 2px #fff, 0 0 0 2px #2563eb; }
        .red-pill-btn { background: #ff0000; color: white !important; border: none; border-radius: 20px; padding: 6px 16px; font-weight: bold; cursor: pointer; flex-shrink:0; font-size: 14px; }
        .red-circle-btn { background: #ff0000; color: white !important; border: none; border-radius: 50%; width: 32px; height: 32px; font-weight: bold; cursor: pointer; flex-shrink:0; font-size: 16px; display:flex; align-items:center; justify-content:center;}
        
        /* 底部滑块区 */
        .slider-label { font-size: 14px; font-weight: bold; margin-right: 4px; flex-shrink:0; }
        input[type=range] { -webkit-appearance: none; width: 100px; height: 4px; background: #ccc; border-radius: 2px; outline: none; margin-right: 15px; }
        input[type=range]::-webkit-slider-thumb { -webkit-appearance: none; appearance: none; width: 16px; height: 16px; border-radius: 50%; background: #666; border: 2px solid #3b82f6; cursor: pointer; }
        
        /* iOS风格 Toggle 开关 */
        .toggle-wrapper { display: flex; align-items: center; gap: 8px; margin-left: auto; }
        .toggle-switch { position: relative; display: inline-block; width: 44px; height: 24px; flex-shrink:0; }
        .toggle-switch input { opacity: 0; width: 0; height: 0; }
        .slider-toggle { position: absolute; cursor: pointer; top: 0; left: 0; right: 0; bottom: 0; background-color: #ccc; transition: .4s; border-radius: 24px; }
        .slider-toggle:before { position: absolute; content: ""; height: 18px; width: 18px; left: 3px; bottom: 3px; background-color: white; transition: .4s; border-radius: 50%; }
        input:checked + .slider-toggle { background-color: #00d22c; }
        input:checked + .slider-toggle:before { transform: translateX(20px); }

        /* 画笔层 */
        #ann-canvas {
            position: fixed; top: 0; left: 0; width: 100vw; height: 100vh;
            z-index: ${MAX_Z - 1}; display: block; cursor: crosshair; 
            pointer-events: none !important; 
            transition: visibility 0.2s;
        }
        .pen-icon-adjust { transform: scale(0.8) !important; }
    `);

    // ================= [DOM 构建与初始化] =================
    const canvas = document.createElement('canvas');
    canvas.id = 'ann-canvas';
    document.body.appendChild(canvas);
    const ctx = canvas.getContext('2d');

    const toolbar = document.createElement('div');
    toolbar.id = 'ann-toolbar';
    toolbar.className = 'glass-ui';
    document.body.appendChild(toolbar);

    function createIcon(iconKey) {
        const div = document.createElement('div');
        div.className = 'pill-icon-custom';
        div.style.webkitMaskImage = `url("${ICONS[iconKey]}")`;
        div.style.maskImage = `url("${ICONS[iconKey]}")`;
        return div;
    }

    function makeRubbable(el) {
        if (!el || el.id === 'ann-toolbar') return;
        let isDown = false;
        let rect;
        let centerX, centerY;

        const updateGlow = (e) => {
            const clientX = e.clientX;
            const clientY = e.clientY;
            el.style.setProperty('--mx', `${clientX - rect.left}px`);
            el.style.setProperty('--my', `${clientY - rect.top}px`);
        };

        const onDown = (e) => {
            if (e.cancelable) e.preventDefault();
            isDown = true;
            el.classList.add('rubbing');
            el.setPointerCapture(e.pointerId);
            
            rect = el.getBoundingClientRect();
            centerX = rect.left + rect.width / 2;
            centerY = rect.top + rect.height / 2;
            updateGlow(e);
        };

        const onMove = (e) => {
            if (!isDown) return;
            const clientX = e.clientX;
            const clientY = e.clientY;
            
            const dx = clientX - centerX, dy = clientY - centerY;
            const nx = Math.max(-1, Math.min(1, dx / (rect.width / 2)));
            const ny = Math.max(-1, Math.min(1, dy / (rect.height / 2)));
            
            el.style.setProperty('--rub-tx', `${nx * 4}px`);
            el.style.setProperty('--rub-ty', `${ny * 4}px`);
            el.style.setProperty('--rub-sx', (1 + Math.abs(nx) * 0.15 - Math.abs(ny) * 0.05).toFixed(3));
            el.style.setProperty('--rub-sy', (1 + Math.abs(ny) * 0.15 - Math.abs(nx) * 0.05).toFixed(3));
            updateGlow(e);

            const hoverEl = document.elementFromPoint(clientX, clientY);
            const targetBtn = hoverEl?.closest('button');
            el.querySelectorAll('button').forEach(btn => {
                if(btn === targetBtn) {
                    btn.style.opacity = "1";
                    btn.style.transform = "scale(1.2)";
                } else {
                    btn.style.opacity = "";
                    btn.style.transform = "";
                }
            });
        };

        const onUp = (e) => {
            if (!isDown) return;
            isDown = false;
            
            el.releasePointerCapture(e.pointerId);
            el.classList.remove('rubbing');
            
            el.style.setProperty('--rub-tx', `0px`);
            el.style.setProperty('--rub-ty', `0px`);
            el.style.setProperty('--rub-sx', `1`);
            el.style.setProperty('--rub-sy', `1`);
            el.querySelectorAll('button').forEach(btn => {
                btn.style.opacity = "";
                btn.style.transform = "";
            });

            // 【修复】Bug2: 按钮下半部分判定不灵敏，采用欧几里得距离就近匹配
            const finalX = e.clientX;
            const finalY = e.clientY;
            
            let targetBtn = null;
            let minDist = 35; // 最大容错半径设为 35px
            
            el.querySelectorAll('button').forEach(btn => {
                const bRect = btn.getBoundingClientRect();
                const cx = bRect.left + bRect.width / 2;
                const cy = bRect.top + bRect.height / 2;
                const dist = Math.hypot(finalX - cx, finalY - cy);
                if (dist < minDist) {
                    minDist = dist;
                    targetBtn = btn;
                }
            });

            if (targetBtn && typeof targetBtn.handleAction === 'function') {
                if (navigator.vibrate) navigator.vibrate(10);
                targetBtn.handleAction();
            }
        };

        el.addEventListener('pointerdown', onDown);
        el.addEventListener('pointermove', onMove);
        el.addEventListener('pointerup', onUp);
        el.addEventListener('pointercancel', onUp);
    }

    // ================= [UI 渲染逻辑] =================
    const eraserSvg = `<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m7 21-4.3-4.3c-1-1-1-2.5 0-3.4l9.6-9.6c1-1 2.5-1 3.4 0l5.6 5.6c1 1 1 2.5 0 3.4L13 21"/><path d="M22 21H7"/><path d="m5 11 9 9"/></svg>`;

    function renderToolbarUI() {
        toolbar.innerHTML = `
            <div class="ann-row top-row">
                <div class="color-list">
                    ${colors.map(c => `<div class="ann-dot ${state.color===c && state.tool==='brush' ?'active':''}" data-color="${c}" style="background:${c}"></div>`).join('')}
                </div>
                <button id="btn-eraser" class="icon-btn ${state.tool==='eraser'?'active':''}">${eraserSvg}</button>
                <button id="btn-clear" class="red-pill-btn">清屏</button>
                <button id="btn-close" class="red-circle-btn">✕</button>
            </div>
            <div class="ann-row bottom-row">
                <span class="slider-label">粗</span>
                <input type="range" id="thick-slider" min="2" max="20" value="${state.thickness}">
                <span class="slider-label">透</span>
                <input type="range" id="opacity-slider" min="0.1" max="1" step="0.1" value="${state.opacity}">
                
                <div class="toggle-wrapper">
                    <span class="slider-label">手写笔模式</span>
                    <label class="toggle-switch">
                        <input type="checkbox" id="stylus-toggle" ${state.stylusMode ? 'checked' : ''}>
                        <span class="slider-toggle"></span>
                    </label>
                </div>
            </div>
        `;

        toolbar.querySelector('.color-list').addEventListener('pointerdown', (e) => {
            const t = e.target;
            if (t.classList.contains('ann-dot')) { state.color = t.dataset.color; state.tool = 'brush'; renderToolbarUI(); }
        });
        toolbar.querySelector('#btn-eraser').onclick = () => { state.tool = 'eraser'; renderToolbarUI(); };
        toolbar.querySelector('#btn-clear').onclick = () => { state.strokes = []; redraw(); };
        toolbar.querySelector('#btn-close').onclick = () => { toggleAnnotationMode(); };
        
        toolbar.querySelector('#thick-slider').addEventListener('input', (e) => { state.thickness = parseInt(e.target.value); });
        toolbar.querySelector('#opacity-slider').addEventListener('input', (e) => { state.opacity = parseFloat(e.target.value); });
        toolbar.querySelector('#stylus-toggle').addEventListener('change', (e) => { 
            state.stylusMode = e.target.checked; 
        });
    }

    // ================= [批注与核心逻辑区] =================
    function getPageAtPoint(x, y) {
        const pages = document.querySelectorAll('.page');
        for (let i = 0; i < pages.length; i++) {
            const rect = pages[i].getBoundingClientRect();
            if (x >= rect.left && x <= rect.right && y >= rect.top && y <= rect.bottom) { return { index: i, rect: rect }; }
        }
        return null;
    }

    function redraw() {
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        const pages = document.querySelectorAll('.page');
        if (pages.length === 0) return;

        state.strokes.forEach(s => {
            if (s.points.length < 1) return;
            const pageEl = pages[s.pageIndex];
            if (!pageEl) return;
            const rect = pageEl.getBoundingClientRect();
            if (rect.bottom < 0 || rect.top > window.innerHeight) return;

            ctx.beginPath();
            ctx.lineCap = 'round'; ctx.lineJoin = 'round';
            ctx.strokeStyle = s.color; ctx.globalAlpha = s.opacity;
            ctx.lineWidth = s.widthRatio * rect.width;

            s.points.forEach((p, idx) => {
                const px = rect.left + p.rx * rect.width;
                const py = rect.top + p.ry * rect.height;
                if (idx === 0) ctx.moveTo(px, py);
                else ctx.lineTo(px, py);
            });
            ctx.stroke();
        });
    }

    function handleDrawStart(x, y) {
        const target = getPageAtPoint(x, y);
        if (!target) return;
        const rx = (x - target.rect.left) / target.rect.width;
        const ry = (y - target.rect.top) / target.rect.height;
        if (state.tool === 'brush') {
            state.currentStroke = { pageIndex: target.index, color: state.color, opacity: state.opacity, widthRatio: state.thickness / 1000, points: [{ rx, ry }] };
            state.strokes.push(state.currentStroke);
        }
    }

    function handleDrawMove(x, y) {
        if (state.tool === 'brush' && state.currentStroke) {
            const pageEl = document.querySelectorAll('.page')[state.currentStroke.pageIndex];
            if(!pageEl) return;
            const rect = pageEl.getBoundingClientRect();
            state.currentStroke.points.push({ rx: (x - rect.left) / rect.width, ry: (y - rect.top) / rect.height });
            redraw();
        } else if (state.tool === 'eraser') {
            const initialLen = state.strokes.length;
            const pages = document.querySelectorAll('.page');
            state.strokes = state.strokes.filter(s => {
                const pageEl = pages[s.pageIndex];
                if (!pageEl) return true;
                const r = pageEl.getBoundingClientRect();
                const strokeRadius = (s.widthRatio * r.width) / 2 + 15;
                return !s.points.some(p => Math.hypot(x - (r.left + p.rx * r.width), y - (r.top + p.ry * r.height)) < strokeRadius);
            });
            if (state.strokes.length !== initialLen) redraw();
        }
    }

    // --- 全新 Pointer Event 逻辑 ---
    let activePointers = new Map();
    let currentInteractionMode = 'none'; // 'draw', 'pan', 'pan-1', 'wait', 'native-pinch'
    let touchWaitTimer = null;
    let initialTouchData = null;
    let bufferedMoves = [];

    let panStartMidX = 0, panStartMidY = 0;
    let panStartScrollTop = 0, panStartScrollLeft = 0;
    
    // 缩放修正变量
    let pinchStartDist = 0, pinchStartScale = 1, currentScaleFactor = 1;
    let pinchViewportX = 0, pinchViewportY = 0;

    // 【修复】Bug1: 无论是否为手写笔模式，只要进入批注状态，一律禁用原生 Touch-Action 
    // 所有滚动与缩放逻辑皆由本脚本 JS 层面严格控制，阻断浏览器的默认处理（如手写笔滑动画布）
    function updateContainerTouchAction() {
        const vc = document.getElementById('viewerContainer');
        if (!vc) return;
        if (state.active) {
            vc.classList.add('disable-native-touch');
        } else {
            vc.classList.remove('disable-native-touch');
        }
    }

    // 通用JS平移初始化计算
    function setupJSPan(pts) {
        const vc = document.getElementById('viewerContainer');
        if (pts.length === 1) {
            panStartMidX = pts[0].clientX;
            panStartMidY = pts[0].clientY;
        } else {
            panStartMidX = (pts[0].clientX + pts[1].clientX) / 2;
            panStartMidY = (pts[0].clientY + pts[1].clientY) / 2;
        }
        panStartScrollTop = vc.scrollTop;
        panStartScrollLeft = vc.scrollLeft;
    }

    // 通用JS平移执行计算
    function doJSPan(pts) {
        const vc = document.getElementById('viewerContainer');
        let curMidX, curMidY;
        if (pts.length === 1) {
            curMidX = pts[0].clientX;
            curMidY = pts[0].clientY;
        } else {
            curMidX = (pts[0].clientX + pts[1].clientX) / 2;
            curMidY = (pts[0].clientY + pts[1].clientY) / 2;
        }
        vc.scrollLeft = panStartScrollLeft - (curMidX - panStartMidX);
        vc.scrollTop = panStartScrollTop - (curMidY - panStartMidY);
        requestAnimationFrame(redraw);
    }

    // 【关键修改】开启捕获模式 {capture: true} 拦截所有的点击，截断原生行为
    window.addEventListener('pointerdown', (e) => {
        // 如果点在 UI 上，不拦截
        if (e.target.closest('.glass-ui')) return; 

        // 屏蔽浏览器原生滚动条拖拽引发的事件拦截
        const vc = document.getElementById('viewerContainer');
        if (vc) {
            const rect = vc.getBoundingClientRect();
            if (e.clientX > rect.right - 20 || e.clientY > rect.bottom - 20) return; 
        }

        activePointers.set(e.pointerId, e);

        // --- 1. 非批注模式（原生看 PDF 模式） ---
        if (!state.active) {
            if (activePointers.size === 2) {
                const pts = Array.from(activePointers.values());
                currentInteractionMode = 'native-pinch';
                canvas.style.visibility = 'hidden';
                const app = window.unsafeWindow.PDFViewerApplication;
                
                pinchStartDist = Math.hypot(pts[0].clientX - pts[1].clientX, pts[0].clientY - pts[1].clientY);
                pinchStartScale = app.pdfViewer.currentScale;
                
                // 记录相对于 viewerContainer 的双指中心点位置
                const vcRect = document.getElementById('viewerContainer').getBoundingClientRect();
                pinchViewportX = ((pts[0].clientX + pts[1].clientX) / 2) - vcRect.left;
                pinchViewportY = ((pts[0].clientY + pts[1].clientY) / 2) - vcRect.top;
                
                const viewer = document.getElementById('viewer');
                const vRect = viewer.getBoundingClientRect();
                const originX = ((pts[0].clientX + pts[1].clientX) / 2) - vRect.left;
                const originY = ((pts[0].clientY + pts[1].clientY) / 2) - vRect.top;
                viewer.style.transformOrigin = `${originX}px ${originY}px`;
            }
            return;
        }

        // --- 2. 批注模式 ---
        // 彻底阻止浏览器将手写笔动作识别为滚动/前进后退等操作
        if (e.cancelable) e.preventDefault(); 
        
        const pts = Array.from(activePointers.values());

        if (state.stylusMode) {
            // [手写笔模式]：笔画画，手移动
            if (e.pointerType === 'pen') {
                currentInteractionMode = 'draw';
                handleDrawStart(e.clientX, e.clientY);
            } else if (e.pointerType === 'touch' || e.pointerType === 'mouse') {
                if (currentInteractionMode === 'draw') return; // 如果笔在画，忽略手
                currentInteractionMode = pts.length === 1 ? 'pan-1' : 'pan';
                setupJSPan(pts);
            }
        } else {
            // [常规模式]：1指画画，2指移动，笔直接画画
            if (e.pointerType === 'touch' || e.pointerType === 'mouse') {
                if (pts.length === 1) {
                    currentInteractionMode = 'wait';
                    initialTouchData = { x: e.clientX, y: e.clientY };
                    bufferedMoves = [];
                    touchWaitTimer = setTimeout(() => {
                        touchWaitTimer = null;
                        if (currentInteractionMode === 'wait') {
                            currentInteractionMode = 'draw';
                            handleDrawStart(initialTouchData.x, initialTouchData.y);
                            bufferedMoves.forEach(m => handleDrawMove(m.x, m.y));
                            bufferedMoves = [];
                        }
                    }, 150); 
                } else if (pts.length === 2) {
                    if (touchWaitTimer) { clearTimeout(touchWaitTimer); touchWaitTimer = null; }
                    currentInteractionMode = 'pan';
                    state.currentStroke = null; redraw(); // 取消画了一半的线
                    setupJSPan(pts);
                }
            } else if (e.pointerType === 'pen') {
                currentInteractionMode = 'draw';
                handleDrawStart(e.clientX, e.clientY);
            }
        }
    }, { passive: false, capture: true });

    window.addEventListener('pointermove', (e) => {
        if (!activePointers.has(e.pointerId) && !state.active) return;
        
        if (activePointers.has(e.pointerId)) activePointers.set(e.pointerId, e);

        // --- 1. 非批注模式下缩放视觉表现 ---
        if (!state.active && currentInteractionMode === 'native-pinch' && activePointers.size === 2) {
            e.preventDefault();
            const pts = Array.from(activePointers.values());
            currentScaleFactor = Math.hypot(pts[0].clientX - pts[1].clientX, pts[0].clientY - pts[1].clientY) / pinchStartDist;
            document.getElementById('viewer').style.transform = `scale(${currentScaleFactor})`;
            return;
        }

        if (!state.active) return;
        if (e.cancelable) e.preventDefault(); // 批注期间彻底阻断默认滑动

        const pts = Array.from(activePointers.values());

        if (currentInteractionMode === 'draw') {
            if (state.stylusMode && e.pointerType !== 'pen') return; // 笔模式下禁止手势抢占画笔
            handleDrawMove(e.clientX, e.clientY);
        } else if (currentInteractionMode === 'wait') {
            bufferedMoves.push({ x: e.clientX, y: e.clientY });
        } else if (currentInteractionMode.startsWith('pan')) {
            if (e.pointerType === 'pen') return; 
            doJSPan(pts);
        }
    }, { passive: false, capture: true });

    const handlePointerUp = (e) => {
        activePointers.delete(e.pointerId);
        
        // --- 非批注模式缩放松手，进行真实排版缩放与坐标补偿 ---
        if (!state.active && currentInteractionMode === 'native-pinch' && activePointers.size < 2) {
            currentInteractionMode = 'none';
            const app = window.unsafeWindow.PDFViewerApplication;
            const vc = document.getElementById('viewerContainer');
            const viewer = document.getElementById('viewer');
            
            viewer.style.transform = 'none';
            const newScale = Math.max(0.25, Math.min(pinchStartScale * currentScaleFactor, 5.0));
            app.pdfViewer.currentScaleValue = newScale.toFixed(2);
            
            // 【修复】Bug3: 通过比例公式调整滚动条位置，使缩放精准保持在双指中心
            const ratio = 1;
            vc.scrollLeft = (vc.scrollLeft + pinchViewportX) * ratio - pinchViewportX;
            vc.scrollTop = (vc.scrollTop + pinchViewportY) * ratio - pinchViewportY;
            
            canvas.style.visibility = 'visible'; redraw();
        }

        if (!state.active) return;

        if (touchWaitTimer) { clearTimeout(touchWaitTimer); touchWaitTimer = null; }

        if (activePointers.size === 0) {
            currentInteractionMode = 'none';
            state.currentStroke = null;
        } else if (activePointers.size === 1 && currentInteractionMode === 'pan') {
            // 双指变单指防抖
            currentInteractionMode = 'none';
        }
    };

    window.addEventListener('pointerup', handlePointerUp);
    window.addEventListener('pointercancel', handlePointerUp);

    // ================= [UI 开关与动态主题] =================
    let penBtnRef = null;
    function toggleAnnotationMode() {
        state.active = !state.active;
        if (state.active) {
            canvas.width = window.innerWidth; canvas.height = window.innerHeight;
            toolbar.style.display = 'flex';
            if (penBtnRef) penBtnRef.classList.add('active-pen');
            renderToolbarUI(); redraw();
        } else {
            toolbar.style.display = 'none';
            if (penBtnRef) penBtnRef.classList.remove('active-pen');
            activePointers.clear();
            currentInteractionMode = 'none';
        }
        updateContainerTouchAction();
    }

    window.addEventListener('resize', () => { canvas.width = window.innerWidth; canvas.height = window.innerHeight; redraw(); });

    function getBrightnessFromElement(x, y) {
        const els = document.elementsFromPoint(x, y);
        for (let el of els) {
            if (el.closest('.glass-ui') || el.id === 'ann-canvas') continue;
            if (el.tagName.toLowerCase() === 'canvas') {
                try {
                    const ctx = el.getContext('2d');
                    const rect = el.getBoundingClientRect();
                    const pixel = ctx.getImageData(Math.floor((x - rect.left) * (el.width/rect.width)), Math.floor((y - rect.top) * (el.height/rect.height)), 1, 1).data;
                    if (pixel[3] > 0) return (pixel[0] * 299 + pixel[1] * 587 + pixel[2] * 114) / 1000;
                } catch(e) {}
            } else {
                const bg = window.getComputedStyle(el).backgroundColor;
                if (bg && bg !== 'transparent' && !bg.match(/rgba\([^,]+,[^,]+,[^,]+,\s*0\)/)) {
                    const match = bg.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)/);
                    if (match) return (parseInt(match[1]) * 299 + parseInt(match[2]) * 587 + parseInt(match[3]) * 114) / 1000;
                }
            }
        }
        return 255;
    }

    function checkPillsTheme() {
        const check = (ui) => {
            if (!ui || ui.style.display === 'none') return;
            const rect = ui.getBoundingClientRect();
            if (rect.width === 0) return;
            const midlineY = rect.top + rect.height / 2;
            const relativePositions = [1, 3, 5, 7, 9];
            const step = rect.width / 10; 
            let anyDark = false; 
            for (let pos of relativePositions) {
                if (getBrightnessFromElement(rect.left + pos * step, midlineY) < 95) { anyDark = true; break; }
            }
            if (anyDark) ui.classList.add('dark-theme'); else ui.classList.remove('dark-theme');
        };
        check(document.querySelector('.left-pill')); check(document.querySelector('.right-pill')); check(document.querySelector('#ann-toolbar'));
    }
    setInterval(checkPillsTheme, 500);

function initPills() {
        const app = window.unsafeWindow.PDFViewerApplication;
        const container = document.getElementById('outerContainer');

        // ---- 左侧药丸 ----
        const leftPill = document.createElement('div');
        leftPill.className = 'glass-ui custom-pill left-pill';
        leftPill.style.left = '20px'; leftPill.style.width = '112px'; leftPill.style.padding = '0 12px';

        const btnSide = document.createElement('button');
        btnSide.appendChild(createIcon('sidebar'));
        btnSide.handleAction = () => app.pdfSidebar.toggle(); 

        const btnIn = document.createElement('button');
        btnIn.appendChild(createIcon('zoomIn'));
        btnIn.handleAction = () => app.zoomIn(); 

        const btnOut = document.createElement('button');
        btnOut.appendChild(createIcon('zoomOut'));
        btnOut.handleAction = () => app.zoomOut(); 

        leftPill.append(btnSide, btnIn, btnOut);

        // ---- 右侧药丸 ----
        const rightPill = document.createElement('div');
        rightPill.className = 'glass-ui custom-pill right-pill';
        rightPill.style.right = '20px';
        if (featureLimit === 1) { rightPill.style.width = '115px'; rightPill.style.padding = '0 10px'; }
        else { rightPill.style.width = '145px'; rightPill.style.padding = '0 8px'; }

        const btnInfo = document.createElement('button');
        btnInfo.appendChild(createIcon('info'));
        btnInfo.handleAction = () => app.pdfDocumentProperties.open();

        let btnDl = null;
        if (featureLimit !== 1) {
            btnDl = document.createElement('button');
            btnDl.appendChild(createIcon('download'));
            btnDl.handleAction = () => app.downloadOrSave();
        }

        const btnSearch = document.createElement('button');
        btnSearch.appendChild(createIcon('search'));
        btnSearch.handleAction = () => { if(app.findBar) app.findBar.toggle(); };

        const btnPen = document.createElement('button');
        const penIcon = createIcon('pen'); penIcon.classList.add('pen-icon-adjust');
        btnPen.appendChild(penIcon); penBtnRef = btnPen;
        btnPen.handleAction = () => toggleAnnotationMode();

        if (featureLimit === 1) rightPill.append(btnInfo, btnSearch, btnPen);
        else rightPill.append(btnInfo, btnDl, btnSearch, btnPen);

        makeRubbable(leftPill);
        makeRubbable(rightPill);

        container.appendChild(leftPill);
        container.appendChild(rightPill);

        const vc = document.getElementById('viewerContainer');
        vc.addEventListener('scroll', () => { if(state.strokes.length) redraw(); }, {passive:true});
    }

    const checkApp = setInterval(() => {
        const app = window.unsafeWindow.PDFViewerApplication;
        if (app && app.initialized) { clearInterval(checkApp); initPills(); }
    }, 100);
})();