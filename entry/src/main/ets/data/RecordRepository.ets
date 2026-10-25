/**
 * 鹿了么 - 记录数据仓库（RelationalStore / SQLite）
 *
 * 所有数据仅保存在本机应用沙箱内，模块不申请任何网络权限。
 */
import { relationalStore } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Record } from '../model/RecordModel';

const STORE_CONFIG: relationalStore.StoreConfig = {
  name: 'luleme.db',
  securityLevel: relationalStore.SecurityLevel.S1
};

const CREATE_TABLE_SQL: string = `CREATE TABLE IF NOT EXISTS records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp INTEGER NOT NULL,
  mood INTEGER NOT NULL,
  note TEXT NOT NULL
)`;

/** 记录变更监听器（新增 / 修改 / 删除 / 清空后触发） */
export type RecordsChangedHandler = () => void;

export class RecordRepository {
  private static instance: RecordRepository | null = null;
  private store: relationalStore.RdbStore | null = null;
  /**
   * 初始化中的 Promise。
   * EntryAbility.onCreate 里的 init() 是「发了不等」的，而首页 aboutToAppear 会立刻读库；
   * 这里把首次初始化缓存下来，读写前先 await 它，避免「首帧读库时句柄还没建好 → 静默返回空数组」。
   */
  private initPromise: Promise<void> | null = null;
  private listeners: RecordsChangedHandler[] = [];

  static getInstance(): RecordRepository {
    if (RecordRepository.instance === null) {
      RecordRepository.instance = new RecordRepository();
    }
    return RecordRepository.instance;
  }

  /** 初始化数据库（幂等），必须在首次读写前调用 */
  init(context: common.Context): Promise<void> {
    if (this.initPromise === null) {
      this.initPromise = this.doInit(context);
    }
    return this.initPromise;
  }

  private async doInit(context: common.Context): Promise<void> {
    const store = await relationalStore.getRdbStore(context, STORE_CONFIG);
    await store.executeSql(CREATE_TABLE_SQL);
    this.store = store;
  }

  private async requireStore(): Promise<relationalStore.RdbStore> {
    if (this.store !== null) {
      return this.store;
    }
    if (this.initPromise !== null) {
      await this.initPromise;
    }
    if (this.store === null) {
      throw new Error('RecordRepository not initialized');
    }
    return this.store;
  }

  /**
   * 订阅记录变更。
   *
   * 首页是常驻页面，RecordEdit 保存后只是把 NavDestination 弹栈，
   * Entry 页的 onPageShow 不会重新触发，于是日历/统计永远停在旧数据上。
   * 所有写操作完成后统一广播一次，由页面自己决定刷新。
   */
  subscribe(handler: RecordsChangedHandler): void {
    if (this.listeners.indexOf(handler) < 0) {
      this.listeners.push(handler);
    }
  }

  unsubscribe(handler: RecordsChangedHandler): void {
    const index = this.listeners.indexOf(handler);
    if (index >= 0) {
      this.listeners.splice(index, 1);
    }
  }

  private notifyChanged(): void {
    // 复制一份再遍历，避免回调里取消订阅导致遍历错位
    const snapshot: RecordsChangedHandler[] = this.listeners.slice();
    for (let i = 0; i < snapshot.length; i++) {
      snapshot[i]();
    }
  }

  /** 新增记录，返回新记录的 id */
  async add(timestamp: number, mood: number, note: string): Promise<number> {
    const values: relationalStore.ValuesBucket = {
      'timestamp': timestamp,
      'mood': mood,
      'note': note
    };
    const id = await (await this.requireStore()).insert('records', values);
    this.notifyChanged();
    return id;
  }

  /** 更新记录 */
  async update(id: number, timestamp: number, mood: number, note: string): Promise<void> {
    const values: relationalStore.ValuesBucket = {
      'timestamp': timestamp,
      'mood': mood,
      'note': note
    };
    const predicates = new relationalStore.RdbPredicates('records');
    predicates.equalTo('id', id);
    await (await this.requireStore()).update(values, predicates);
    this.notifyChanged();
  }

  /** 删除记录 */
  async remove(id: number): Promise<void> {
    const predicates = new relationalStore.RdbPredicates('records');
    predicates.equalTo('id', id);
    await (await this.requireStore()).delete(predicates);
    this.notifyChanged();
  }

  /** 清空全部记录 */
  async clearAll(): Promise<void> {
    await (await this.requireStore()).executeSql('DELETE FROM records');
    this.notifyChanged();
  }

  /** 全部记录（按时间降序） */
  async getAll(): Promise<Record[]> {
    const resultSet = await (await this.requireStore()).querySql(
      'SELECT id, timestamp, mood, note FROM records ORDER BY timestamp DESC');
    return this.readResultSet(resultSet);
  }

  /** 按 id 查询单条记录 */
  async getById(id: number): Promise<Record | null> {
    const resultSet = await (await this.requireStore()).querySql(
      'SELECT id, timestamp, mood, note FROM records WHERE id = ?', [id]);
    const list = this.readResultSet(resultSet);
    if (list.length === 0) {
      return null;
    }
    return list[0];
  }

  private readResultSet(resultSet: relationalStore.ResultSet): Record[] {
    const list: Record[] = [];
    try {
      while (resultSet.goToNextRow()) {
        const record: Record = {
          id: resultSet.getLong(resultSet.getColumnIndex('id')),
          timestamp: resultSet.getLong(resultSet.getColumnIndex('timestamp')),
          mood: resultSet.getLong(resultSet.getColumnIndex('mood')),
          note: resultSet.getString(resultSet.getColumnIndex('note'))
        };
        list.push(record);
      }
    } finally {
      resultSet.close();
    }
    return list;
  }
}
