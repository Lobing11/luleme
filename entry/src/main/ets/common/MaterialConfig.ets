/**
 * 鹿了么 - 沉浸光感（HDS 材质）配置中心
 *
 * 统一管理 HDS systemMaterialEffect 的材质档位与设备能力适配：
 * - 档位：EXQUISITE（强）/ GENTLE（均衡）/ SMOOTH（弱）/ ADAPTIVE（自适应，推荐）
 * - 设备能力：通过 hdsMaterial.getSystemMaterialTypes() 查询，低端设备自动降级为 NONE
 * - 亮色模式：EXQUISITE 可能覆盖白色叠层，非白纯色底色可切换至 GENTLE
 */
import { hdsMaterial, SystemMaterialParams } from '@kit.UIDesignKit';

/** Settings 持久化 key */
export const MATERIAL_LEVEL_KEY: string = 'material_level';

/** 默认档位：自适应 */
export const DEFAULT_MATERIAL_LEVEL: number = hdsMaterial.MaterialLevel.ADAPTIVE;

export interface MaterialLevelOption {
  key: hdsMaterial.MaterialLevel;
  label: string;
  desc: string;
}

export const MATERIAL_LEVEL_OPTIONS: MaterialLevelOption[] = [
  { key: hdsMaterial.MaterialLevel.ADAPTIVE, label: '自适应', desc: '跟随系统策略（推荐）' },
  { key: hdsMaterial.MaterialLevel.EXQUISITE, label: '精致', desc: '强光效·模拟物理光照' },
  { key: hdsMaterial.MaterialLevel.GENTLE, label: '均衡', desc: '中度光效' },
  { key: hdsMaterial.MaterialLevel.SMOOTH, label: '柔和', desc: '弱光效·省电' }
];

/** 查询本机支持的 HDS 材质类型；失败时按不支持处理 */
export function querySystemMaterialTypes(): hdsMaterial.MaterialType[] {
  try {
    return hdsMaterial.getSystemMaterialTypes();
  } catch (err) {
    return [hdsMaterial.MaterialType.NONE];
  }
}

/** 解析本机应使用的材质类型：优先 ADAPTIVE，其次 IMMERSIVE，否则 NONE（关闭沉浸光感） */
export function resolveMaterialType(): hdsMaterial.MaterialType {
  const types = querySystemMaterialTypes();
  if (types.indexOf(hdsMaterial.MaterialType.ADAPTIVE) >= 0) {
    return hdsMaterial.MaterialType.ADAPTIVE;
  }
  if (types.indexOf(hdsMaterial.MaterialType.IMMERSIVE) >= 0) {
    return hdsMaterial.MaterialType.IMMERSIVE;
  }
  return hdsMaterial.MaterialType.NONE;
}

/** 本机是否支持沉浸光感 */
export function supportsImmersiveMaterial(): boolean {
  return resolveMaterialType() !== hdsMaterial.MaterialType.NONE;
}

/** 将持久化的数值规整为合法档位；未知值回退到 ADAPTIVE */
export function sanitizeMaterialLevel(value: number): hdsMaterial.MaterialLevel {
  const options = MATERIAL_LEVEL_OPTIONS;
  for (let i = 0; i < options.length; i++) {
    if (value === options[i].key) {
      return options[i].key;
    }
  }
  return hdsMaterial.MaterialLevel.ADAPTIVE;
}

/** 档位中文名 */
export function materialLevelLabel(level: hdsMaterial.MaterialLevel): string {
  const options = MATERIAL_LEVEL_OPTIONS;
  for (let i = 0; i < options.length; i++) {
    if (level === options[i].key) {
      return options[i].label;
    }
  }
  return MATERIAL_LEVEL_OPTIONS[0].label;
}

/** 构建 HDS SystemMaterialParams（供 HdsNavigation.titleBar / HdsTabs.barFloatingStyle 使用） */
export function buildSystemMaterialParams(level: hdsMaterial.MaterialLevel): SystemMaterialParams {
  return {
    materialType: resolveMaterialType(),
    materialLevel: sanitizeMaterialLevel(level)
  };
}
