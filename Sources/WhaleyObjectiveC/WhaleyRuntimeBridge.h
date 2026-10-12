#if __has_include(<UIKit/UIKit.h>)
#pragma once
#include <stddef.h>
#include <stdint.h>

void *WhaleyGameActionMoveTo(double x, double y, double seconds);
void *WhaleyGameActionScaleTo(double scale, double seconds);
void *WhaleyGameActionRotateBy(double degrees, double seconds);
void *WhaleyGameActionWait(double seconds);
void *WhaleyGameActionFade(double durationSeconds, double opacity);
void *WhaleyGameActionSequence(void *const *actions, size_t count);
void *WhaleyGameActionRepeatForever(void *action);
void *WhaleyGameActionAnimate(const char *const *frameNames, size_t count, double frameSeconds);

void *WhaleyRenderGameAction(void *action, void *ownerNode);
void WhaleyReleaseGameAction(void *action);
void WhaleyReleaseRenderedObject(void *object);

void *WhaleyTileMapCreate(int width, int height, double tileWidth, double tileHeight);
void WhaleyTileMapSetLayer(void *map, const char *name, const uint32_t *gids, size_t count);
uint32_t WhaleyTileMapGID(void *map, const char *layer, int column, int row);
void WhaleyTileMapSetGID(void *map, const char *layer, int column, int row, uint32_t gid);
void WhaleyReleaseTileMap(void *map);

typedef void (*WhaleyActionCallback)(void *context, void *node);
uint64_t WhaleyRegisterActionCallback(void *context, WhaleyActionCallback callback);
void *WhaleyGameActionCallback(uint64_t callbackID);

typedef void (*WhaleyScheduledCallback)(void *context, double dt);
void *WhaleySchedulerCreate(void);
uint64_t WhaleySchedulerSchedule(void *scheduler, double interval, void *context, WhaleyScheduledCallback callback);
void WhaleySchedulerCancel(void *scheduler, uint64_t scheduleID);
void WhaleySchedulerAdvance(void *scheduler, double delta);
void WhaleyReleaseScheduler(void *scheduler);

void WhaleyRegisterSpriteFrame(const char *name, const char *atlas, double x, double y, double width, double height, double atlasWidth, double atlasHeight);
void WhaleyRegisterMissingSpriteFrame(const char *name);
#endif
