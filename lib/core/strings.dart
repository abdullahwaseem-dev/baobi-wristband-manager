class S {
  static String lang = 'en';

  static bool get isZh => lang == 'zh';
  static bool get isAr => lang == 'ar';

  static String _s(String en, String zh, String ar) {
    if (isZh) return zh;
    if (isAr) return ar;
    return en;
  }

  // App
  static String get appName    => _s('BAOBI Medical Wristband', 'BAOBI 医疗腕带', 'باوبي للأساور الطبية');
  static String get manufacturer => 'Baobiwanxiang Technologies Co.,Limited';

  // Nav
  static String get navHome        => _s('Home',         '首页',   'الرئيسية');
  static String get navPrint       => _s('Print',        '打印',   'طباعة');
  static String get navPatientList => _s('Patient List', '患者列表', 'قائمة المرضى');
  static String get navPrintQueue  => _s('Print Queue',  '打印队列', 'قائمة الطباعة');

  // Status bar
  static String get readyToPrint => _s('Ready to Print', '就绪打印', 'جاهز للطباعة');
  static String get printCount   => _s('Print Tasks',    '打印任务', 'مهام الطباعة');
  static String get notReady     => _s('Not Ready',      '未就绪',  'غير جاهز');

  // Home
  static String get systemSettings  => _s('System Settings',  '系统设置',  'إعدادات النظام');
  static String get printSettings   => _s('Print Settings',   '打印设置',  'إعدادات الطباعة');
  static String get setWifi         => _s('Set WiFi',         '设置 WiFi', 'إعداد الواي فاي');
  static String get setPassword     => _s('Set Password',     '设置密码',  'تعيين كلمة المرور');
  static String get firmwareVersion => _s('Firmware Version', '固件版本',  'إصدار البرنامج');
  static String get printSpeed      => _s('Print Speed',      '打印速度',  'سرعة الطباعة');
  static String get printDensity    => _s('Print Density',    '打印浓度',  'كثافة الطباعة');
  static String get recentPatients  => _s('Recent Patients',  '最近患者',  'المرضى الأخيرون');
  static String get recentPrints    => _s('Recent Prints',    '最近打印',  'الطباعة الأخيرة');
  static String get viewAll         => _s('View All',         '查看全部',  'عرض الكل');

  // Print screen
  static String get manualPrint           => _s('Manual Print',         '手动打印',         'طباعة يدوية');
  static String get patientName           => _s('Patient Name',         '患者姓名',         'اسم المريض');
  static String get gender                => _s('Gender',               '性别',            'الجنس');
  static String get male                  => _s('Male',                 '男',              'ذكر');
  static String get female                => _s('Female',               '女',              'أنثى');
  static String get patientId             => _s('Patient ID',           '住院号',           'رقم المريض');
  static String get allergy               => _s('Allergy History',      '过敏史',           'تاريخ الحساسية');
  static String get bloodType             => _s('Blood Type',           '血型',            'فصيلة الدم');
  static String get department            => _s('Department',           '科室',            'القسم');
  static String get doctor                => _s('Doctor',               '主治医师',         'الطبيب');
  static String get dateOfBirth           => _s('Date of Birth',        '出生日期',         'تاريخ الميلاد');
  static String get admissionTime         => _s('Admission Time',       '入院时间',         'وقت الدخول');
  static String get defaultBtn            => _s('Default',              '默认',            'افتراضي');
  static String get clearBtn              => _s('Clear',                '清除',            'مسح');
  static String get printBtn              => _s('Print',                '打印',            'طباعة');
  static String get syncHis               => _s('Sync HIS',             'HIS 同步',        'مزامنة HIS');
  static String get patientIdPlaceholder  => _s('e.g. 123456',          '例如: 123456',    'مثال: 123456');
  static String get namePlaceholder       => _s('Patient full name',    '患者全名',         'الاسم الكامل للمريض');
  static String get allergyPlaceholder    => _s('None / Penicillin, etc','无 / 青霉素 等',  'لا يوجد / بنسلين، إلخ');
  static String get departmentPlaceholder => _s('e.g. Internal Medicine','例如: 内科',      'مثال: الباطنية');
  static String get doctorPlaceholder     => _s('e.g. Dr. Li',          '例如: 李医生',    'مثال: د. أحمد');
  static String get dobPlaceholder        => _s('YYYY.MM.DD',           'YYYY.MM.DD',     'YYYY.MM.DD');
  static String get admissionPlaceholder  => _s('YYYY.MM.DD HH:MM',    'YYYY.MM.DD HH:MM','YYYY.MM.DD HH:MM');

  // Patient list
  static String get patientListTitle    => _s('Patient List',      '患者列表',      'قائمة المرضى');
  static String get searchPlaceholder   => _s('Search name or ID...','搜索姓名或ID...','ابحث عن اسم أو رقم...');
  static String get filter              => _s('Filter',            '筛选',         'تصفية');
  static String get add                 => _s('Add',               '添加',         'إضافة');
  static String get delete              => _s('Delete',            '删除',         'حذف');
  static String get edit                => _s('Edit',              '编辑',         'تعديل');
  static String get importData          => _s('Import',            '导入',         'استيراد');
  static String get exportData          => _s('Export',            '导出',         'تصدير');
  static String get loadedOf            => _s('Loaded',            '已加载',       'تم التحميل');
  static String get totalPatients       => _s('Total patients',    '总患者数',     'إجمالي المرضى');
  static String get noPatients          => _s('No patient records','暂无患者记录', 'لا توجد سجلات مرضى');
  static String get admissionTimeShort  => _s('Admission',         '入院时间',     'الدخول');

  // Print queue
  static String get printQueueTitle  => _s('Print Queue',       '打印队列',     'قائمة الطباعة');
  static String get epcCode          => _s('EPC Code',          'EPC 代码',    'رمز EPC');
  static String get tidCode          => _s('TID Code',          'TID 代码',    'رمز TID');
  static String get printTime        => _s('Print Time',        '打印时间',     'وقت الطباعة');
  static String get totalPrints      => _s('Total prints',      '总打印数',     'إجمالي الطباعة');
  static String get noPrintRecords   => _s('No print records',  '暂无打印记录', 'لا توجد سجلات طباعة');

  // Dialogs
  static String get cancel  => _s('Cancel',  '取消', 'إلغاء');
  static String get ok      => _s('OK',      '确定', 'موافق');
  static String get save    => _s('Save',    '保存', 'حفظ');
  static String get close   => _s('Close',   '关闭', 'إغلاق');
  static String get confirm => _s('Confirm', '确认', 'تأكيد');
  static String get warning => _s('Warning', '警告', 'تحذير');
  static String get success => _s('Success', '成功', 'نجاح');
  static String get error   => _s('Error',   '错误', 'خطأ');

  // WiFi dialog
  static String get wifiConfig        => _s('WiFi Configuration', 'WiFi 配置',  'إعداد الواي فاي');
  static String get availableNetworks => _s('Available Networks', '可用网络',   'الشبكات المتاحة');
  static String get wifiPassword      => _s('WiFi Password',      'WiFi 密码',  'كلمة مرور الواي فاي');
  static String get connect           => _s('Connect',            '连接',       'اتصال');
  static String get scanning          => _s('Scanning...',        '扫描中...',  'جارٍ الفحص...');
  static String get enterWifiPassword => _s('Enter password',     '请输入密码', 'أدخل كلمة المرور');
  static String get connected         => _s('Connected',          '已连接',     'متصل');

  // Password dialog
  static String get enterAdminPassword => _s('Enter administrator password', '请输入管理员密码',   'أدخل كلمة مرور المسؤول');
  static String get passwordConfig     => _s('Password Setup',               '密码设置',         'إعداد كلمة المرور');
  static String get oldPassword        => _s('Old Password',                 '旧密码',           'كلمة المرور القديمة');
  static String get newPassword        => _s('New Password',                 '新密码',           'كلمة المرور الجديدة');
  static String get confirmPassword    => _s('Confirm Password',             '确认密码',         'تأكيد كلمة المرور');
  static String get passwordMismatch   => _s('Passwords do not match',       '两次输入密码不一致','كلمات المرور غير متطابقة');
  static String get wrongPassword      => _s('Incorrect password',           '密码错误',         'كلمة المرور غير صحيحة');
  static String get passwordSaved      => _s('Password saved',               '密码已保存',       'تم حفظ كلمة المرور');

  // Firmware dialog
  static String get firmwareInfo   => _s('Firmware Version Info', '固件版本信息', 'معلومات إصدار البرنامج');
  static String get currentVersion => _s('Current Version',       '当前版本',    'الإصدار الحالي');
  static String get checkUpdate    => _s('Check for Update',      '检查更新',    'التحقق من التحديثات');
  static String get upToDate       => _s('Up to date',            '已是最新版本', 'محدّث');

  // Speed/density dialog
  static String get selectGear    => _s('Select Gear',           '选择档位', 'اختر الدرجة');
  static String get speedConfig   => _s('Print Speed Setting',   '打印速度设置', 'إعداد سرعة الطباعة');
  static String get densityConfig => _s('Print Density Setting', '打印浓度设置', 'إعداد كثافة الطباعة');
  static String get gear          => _s('Gear',                  '档',      'درجة');
  static String get currentGear   => _s('Current Gear',          '当前档位', 'الدرجة الحالية');

  // Clear local data
  static String get clearLocalData      => _s('Clear Local Data', '清除本地数据', 'مسح البيانات المحلية');
  static String get clearDataTitle      => _s('Clear Local Data', '清除本地数据', 'مسح البيانات المحلية');
  static String get clearDataWarning    => _s(
    'This permanently deletes every patient record and print history stored on this PC. This cannot be undone.',
    '此操作将永久删除本机上存储的所有患者记录和打印历史，且无法撤销。',
    'سيؤدي هذا إلى حذف جميع سجلات المرضى وسجل الطباعة المخزنة على هذا الجهاز بشكل نهائي. لا يمكن التراجع عن هذا الإجراء.',
  );
  static String get clearDataConfirmBtn => _s('Clear Everything', '清除所有数据', 'مسح كل شيء');
  static String get clearDataSuccess    => _s('Local data cleared', '本地数据已清除', 'تم مسح البيانات المحلية');

  // Validation / feedback
  static String get fieldRequired  => _s('This field is required',            '此字段为必填项',        'هذا الحقل مطلوب');
  static String get invalidFormat  => _s('Invalid format',                    '格式不正确',           'صيغة غير صحيحة');
  static String get printSuccess   => _s('Print job submitted',               '打印任务已提交',        'تم إرسال مهمة الطباعة');
  static String get printFailed    => _s('Print failed, check printer',       '打印失败，请检查打印机', 'فشل الطباعة، تحقق من الطابعة');
  static String get saveSuccess    => _s('Saved successfully',                '保存成功',             'تم الحفظ بنجاح');
  static String get deleteConfirm  => _s('Delete this patient record?',       '确定要删除此患者记录吗？','حذف سجل المريض؟');
  static String get importSuccess  => _s('Import successful',                 '导入成功',             'تم الاستيراد بنجاح');
  static String get exportSuccess  => _s('Export successful',                 '导出成功',             'تم التصدير بنجاح');
  static String get syncSuccess    => _s('Sync successful',                   '同步成功',             'تمت المزامنة بنجاح');
  static String get syncFailed     => _s('Sync failed, check network',        '同步失败，请检查网络',  'فشل المزامنة، تحقق من الشبكة');
  static String get hisPullSuccess => _s('HIS data synced',                   'HIS 数据同步成功',     'تمت مزامنة بيانات HIS');
  static String get hisPullFailed  => _s('Patient not found or network error','未找到该患者或网络错误','المريض غير موجود أو خطأ في الشبكة');

  // Patient detail
  static String get patientDetail => _s('Patient Details', '患者详情', 'تفاصيل المريض');
  static String get editPatient   => _s('Edit Patient',    '编辑患者', 'تعديل المريض');

  // Paper / printer settings
  static String get paperSize         => _s('Paper Size',                           '纸张规格',                        'حجم الورق');
  static String get selectPaper       => _s('Select Paper Configuration',           '选择纸张型号',                    'اختر تهيئة الورق');
  static String get paperSaved        => _s('Paper configuration saved',            '纸张配置已保存',                   'تم حفظ تهيئة الورق');
  static String get printerName       => _s('Printer Name (Windows)',               '打印机名称 (Windows)',             'اسم الطابعة (ويندوز)');
  static String get printerNameHelper => _s('Must match name in Windows Devices & Printers','与 Windows 设备和打印机中注册的名称一致','يجب أن يطابق الاسم في أجهزة ويندوز');
  static String get paperFromReference => _s('Baobi reference list',  '宝比参考清单',  'قائمة Baobi المرجعية');
  static String get paperFromSpecSheet => _s('Black-bar spec sheet',  '黑标规格书',    'ورقة مواصفات العلامة السوداء');
  static String get blackBar           => _s('Black bar',             '黑标',         'العلامة السوداء');
  static String get fromLeadEdge       => _s('from lead edge',        '距前端',       'من الحافة الأمامية');
  static String get printStartsAfterBar =>
      _s('printing starts immediately after it', '打印从黑标之后立即开始', 'تبدأ الطباعة بعدها مباشرة');
  static String get printOffset        => _s('Print offset',           '打印偏移',      'إزاحة الطباعة');
  static String get printChannel      => _s('Print Channel',    '打印通道',   'قناة الطباعة');
  static String get channelUpper      => _s('Upper feed',       '上通道',    'التغذية العليا');
  static String get channelLower      => _s('Lower feed',       '下通道',    'التغذية السفلى');
  static String get channelDefault    => _s('Printer default',  '打印机默认', 'افتراضي الطابعة');

  // Filter dialog
  static String get all         => _s('All',           '全部',   'الكل');
  static String get dateFrom    => _s('Date From',     '开始日期', 'من تاريخ');
  static String get dateTo      => _s('Date To',       '结束日期', 'إلى تاريخ');
  static String get applyFilter => _s('Apply Filter',  '应用筛选', 'تطبيق التصفية');

  // Excel import/export
  static String get importExcel  => _s('Import Excel', '导入 Excel', 'استيراد Excel');
  static String get exportExcel  => _s('Export Excel', '导出 Excel', 'تصدير Excel');
  static String get importFailed => _s('Import failed, check file format', '导入失败，请检查文件格式', 'فشل الاستيراد، تحقق من صيغة الملف');
  static String get exportFailed => _s('Export failed', '导出失败', 'فشل التصدير');

  // Pagination
  static String get prevPage => _s('Prev', '上一页', 'السابق');
  static String get nextPage => _s('Next', '下一页', 'التالي');
  static String get page     => _s('Page', '页',    'صفحة');
  static String get of       => _s('of',   '共',    'من');

  // Theme
  static String get darkMode  => _s('Dark Mode',  '深色模式', 'الوضع الداكن');
  static String get lightMode => _s('Light Mode', '浅色模式', 'الوضع الفاتح');

  // Common fields
  static String get username   => _s('Username',  '用户名', 'اسم المستخدم');
  static String get password   => _s('Password',  '密码',   'كلمة المرور');
  static String get bloodGroup => _s('Blood Type', '血型',   'فصيلة الدم');

  // HIS Connection — home screen row
  static String get hisConnection       => _s('HIS Connection',       'HIS 连接',    'اتصال HIS');
  static String get hisConnected        => _s('Connected',            '已连接',      'متصل');
  static String get hisNotConnected     => _s('Not configured',       '未配置',      'غير مُهيأ');
  static String get hisBatchSync        => _s('Sync All Patients',    '批量同步患者', 'مزامنة جميع المرضى');

  // HIS dialog
  static String get hisConnectionTitle    => _s('HIS / Database Connection', 'HIS / 数据库连接',  'اتصال HIS / قاعدة البيانات');
  static String get hisConnectionSubtitle => _s('Connect to your hospital information system', '连接到医院信息系统', 'الاتصال بنظام معلومات المستشفى');
  static String get hisTabConnection => _s('Connection', '连接',      'الاتصال');
  static String get hisTabAuth       => _s('Auth',       '认证',      'المصادقة');
  static String get hisTabEndpoints  => _s('Endpoints',  '接口路径',   'المسارات');
  static String get hisTabMapping    => _s('Field Map',  '字段映射',   'مطابقة الحقول');

  static String get hisServerUrl      => _s('Server Base URL',         '服务器基础URL',  'رابط الخادم');
  static String get hisServerUrlHint  => _s('http://192.168.1.100:8080/api', 'http://192.168.1.100:8080/api', 'http://192.168.1.100:8080/api');
  static String get hisConnectionInfo => _s(
    'Enter the base URL of your HIS REST API. The app will call this URL with the configured endpoints to fetch patient data.',
    '输入您的HIS REST API基础URL。应用将通过配置的接口路径获取患者数据。',
    'أدخل الرابط الأساسي لواجهة برمجة HIS. سيستخدم التطبيق هذا الرابط مع المسارات المهيأة لجلب بيانات المرضى.',
  );
  static String get hisConfigured    => _s('Configured', '已配置', 'تم التهيئة');
  static String get hisNotConfigured => _s('Not configured — enter server URL above', '未配置 — 请输入服务器URL', 'غير مُهيأ — أدخل رابط الخادم أعلاه');

  // Department — sent as its own request parameter on every HIS call, so
  // the HIS can filter/scope patient data by department at the integration
  // level. Distinct from the Field Map's "Department" row (fDepartment),
  // which only tells the app which JSON key holds a department NAME in the
  // HIS's response — this is the department VALUE the app sends out.
  static String get hisDepartment     => _s('Department', '科室', 'القسم');
  static String get hisDepartmentHint => _s(
    'e.g. Cardiology — sent to the HIS as a request parameter so it returns only this department\'s patients',
    '如：心内科 — 将作为请求参数发送给HIS，使其仅返回该科室的患者数据',
    'مثال: أمراض القلب — يُرسل إلى نظام HIS كمعامل طلب لإرجاع مرضى هذا القسم فقط',
  );

  static String get hisAuthType      => _s('Authentication Type', '认证类型',   'نوع المصادقة');
  static String get hisBearerToken   => _s('Bearer Token',        '令牌',       'رمز Bearer');
  static String get hisApiKeyHeader  => _s('API Key Header Name', 'API密钥头名称','اسم رأس مفتاح API');
  static String get hisApiKeyValue   => _s('API Key Value',       'API密钥值',  'قيمة مفتاح API');

  static String get hisSearchEndpoint     => _s('Search Endpoint (by ID)',  '按ID查询接口',  'مسار البحث بالرقم');
  static String get hisSearchEndpointHint => _s('Use {id} as placeholder, e.g. /patient/{id}', '使用 {id} 作为占位符', 'استخدم {id} كمحدد مثل /patient/{id}');
  static String get hisListEndpoint       => _s('List / Batch Endpoint',    '列表/批量接口',  'مسار القائمة/الدُفعة');
  static String get hisSearchResponseKey     => _s('Response Key (single patient)', '单个患者响应键名', 'مفتاح استجابة مريض واحد');
  static String get hisSearchResponseKeyHint => _s('e.g. "data" or "result" — leave empty if the patient object is the root', '如 "data" 或 "result" — 患者对象为根时留空', 'مثل "data" أو "result" — اتركه فارغاً إن كان كائن المريض هو الجذر');
  static String get hisResponseKey        => _s('Response Array Key (patient list)', '患者列表响应数组键名', 'مفتاح مصفوفة قائمة المرضى');
  static String get hisResponseKeyHint    => _s('e.g. "data" or "result.items" — leave empty if root is the array', '如 "data" 或 "result.items" — 根为数组时留空', 'مثل "data" أو "result.items" — اتركه فارغاً إن كان الجذر مصفوفة');
  static String get hisEndpointInfo       => _s(
    'Search: GET {baseUrl}{searchEndpoint}  •  List: GET {baseUrl}{listEndpoint}',
    '查询: GET {baseUrl}{搜索接口}  •  列表: GET {baseUrl}{列表接口}',
    'بحث: GET {baseUrl}{مسار البحث}  •  قائمة: GET {baseUrl}{مسار القائمة}',
  );
  static String get hisFieldMappingInfo   => _s(
    'Map your API\'s JSON field names to the patient fields used in this app.',
    '将您的API的JSON字段名映射到本应用使用的患者字段。',
    'قم بمطابقة أسماء حقول JSON في واجهتك البرمجية مع حقول المرضى في هذا التطبيق.',
  );
  static String get hisTestConnection => _s('Test Connection', '测试连接', 'اختبار الاتصال');

  // Cloud sync (Firebase) — home screen row + login dialog
  static String get cloudSync           => _s('Cloud Sync',            '云同步',       'المزامنة السحابية');
  static String get cloudSignedIn       => _s('Signed in',             '已登录',       'تم تسجيل الدخول');
  static String get cloudNotSignedIn    => _s('Not signed in',         '未登录',       'لم يتم تسجيل الدخول');
  static String get cloudSignInTitle    => _s('Cloud Sync Sign-In',    '云同步登录',    'تسجيل الدخول للمزامنة السحابية');
  static String get cloudSignInSubtitle => _s(
    'Sign in with the account provided for your hospital to sync patients across every station.',
    '使用为您医院提供的账号登录，以便在各工作站之间同步患者数据。',
    'سجل الدخول بالحساب المخصص لمستشفاكم لمزامنة بيانات المرضى بين جميع المحطات.',
  );
  static String get cloudEmail          => _s('Email',                 '邮箱',         'البريد الإلكتروني');
  static String get cloudSignIn         => _s('Sign In',                '登录',         'تسجيل الدخول');
  static String get cloudSignOut        => _s('Sign Out',               '登出',         'تسجيل الخروج');
  static String get cloudSyncNow        => _s('Sync Now',               '立即同步',      'مزامنة الآن');
  static String get cloudSignedInAs     => _s('Signed in as',           '登录账号',      'تم الدخول باسم');
  static String get cloudLastSynced     => _s('Last synced',            '上次同步',      'آخر مزامنة');
  static String get cloudNeverSynced    => _s('Never synced yet',       '尚未同步',      'لم تتم أي مزامنة بعد');
  static String get cloudSignInSuccess  => _s('Signed in successfully', '登录成功',      'تم تسجيل الدخول بنجاح');
  static String get cloudSignedOut      => _s('Signed out',             '已登出',        'تم تسجيل الخروج');
  static String get refreshFromCloud    => _s('Refresh from Cloud',    '从云端刷新',    'تحديث من السحابة');

  // Clear data (local cache vs cloud)
  static String get resetLocalCache        => _s('Reset Local Cache', '重置本地缓存', 'إعادة تعيين الذاكرة المحلية');
  static String get resetLocalCacheWarning => _s(
    'Clears the patient and print records stored on this PC. If Cloud Sync is signed in, they will be pulled back down automatically on the next sync — this does not delete anything from the cloud.',
    '清除本机存储的患者和打印记录。如果已登录云同步，下次同步时将自动重新拉取——不会删除云端的任何数据。',
    'يمسح سجلات المرضى والطباعة المخزنة على هذا الجهاز. إذا كنت مسجلاً الدخول للمزامنة السحابية، سيتم سحبها تلقائياً في المزامنة التالية — لن يتم حذف أي شيء من السحابة.',
  );
  static String get deleteCloudData        => _s('Delete All Cloud Data for This Hospital', '删除此医院的所有云端数据', 'حذف جميع بيانات السحابة لهذا المستشفى');
  static String get deleteCloudDataWarning => _s(
    'This permanently deletes every patient and print record in the cloud for this hospital — affecting every station that syncs with it. This cannot be undone.',
    '此操作将永久删除云端此医院的所有患者和打印记录——将影响所有与之同步的工作站。此操作无法撤销。',
    'سيؤدي هذا إلى حذف جميع سجلات المرضى والطباعة في السحابة لهذا المستشفى بشكل نهائي — مما يؤثر على كل محطة تتم مزامنتها معه. لا يمكن التراجع عن هذا الإجراء.',
  );
  static String get typeConfirmToProceed => _s('Type CONFIRM to proceed', '输入 CONFIRM 以继续', 'اكتب CONFIRM للمتابعة');
}
