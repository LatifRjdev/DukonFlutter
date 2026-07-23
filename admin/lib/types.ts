export interface User {
  id: string;
  name: string;
  phone: string;
  email?: string;
  isAdmin: boolean;
  isActive: boolean;
  createdAt: string;
  _count?: { ownedStores: number };
}

export interface CreateUserByAdminInput {
  name: string;
  phone: string;
  email?: string;
  password?: string;
  createStore?: boolean;
  storeName?: string;
  storeCategory?: string;
  storeCurrency?: string;
  storeAddress?: string;
  storePhone?: string;
}

export interface CreateUserByAdminResult {
  user: {
    id: string;
    phone: string;
    name: string;
    email: string | null;
    isAdmin: boolean;
  };
  store: { id: string; name: string } | null;
  generatedPassword: string | null;
}

export interface Store {
  id: string;
  name: string;
  category?: string;
  ownerId?: string;
  owner?: { id: string; name: string; phone: string };
  isActive: boolean;
  subscription?: {
    plan: string;
    status: string;
    currentPeriodEnd?: string;
  };
  _count?: { products: number; staff: number };
  monthlySalesTotal?: number;
  monthlySalesCount?: number;
  lastSaleDate?: string;
  createdAt: string;
}

export interface Subscription {
  id: string;
  storeId: string;
  plan: string;
  status: string;
  trialEndsAt?: string;
  currentPeriodStart?: string;
  currentPeriodEnd?: string;
  adminDiscount?: number;
  createdAt: string;
  updatedAt?: string;
  store?: { id: string; name: string };
}

export interface Plan {
  id: string;
  name: string;
  price: number;
  maxStores: number;
  maxProducts: number;
  maxStaff: number;
  maxDiscounts: number;
  hasReportsAll: boolean;
  hasExport: boolean;
  hasTelegram: boolean;
  hasAllPush: boolean;
  hasDelivery: boolean;
  hasInventory: boolean;
}

export interface Announcement {
  id: string;
  title: string;
  body: string;
  targetPlan?: string;
  targetStatus?: string;
  recipientCount: number;
  sentAt: string;
  sentBy: string;
}

export interface AuditLog {
  id: string;
  createdAt: string;
  userId: string;
  user?: { id: string; name?: string; phone?: string };
  action: string;
  entityType: string;
  entityId?: string | null;
  details?: unknown;
  ip?: string | null;
}

export interface DashboardStats {
  totalUsers: number;
  totalStores: number;
  activeSubscriptions: number;
  trialSubscriptions: number;
  expiredSubscriptions: number;
  monthlyRevenue: number;
  newUsersThisWeek: number;
  newStoresThisWeek: number;
}

export interface RevenuePoint {
  date: string;
  revenue: number;
}

export interface RegistrationPoint {
  date: string;
  users: number;
  stores: number;
}

export interface PendingPayment {
  id: string;
  subscriptionId: string;
  amount: number;
  currency?: string;
  method?: string;
  status?: string;
  receiptImage?: string;
  note?: string;
  createdAt: string;
  subscription?: {
    id: string;
    plan: string;
    status: string;
    store?: { id: string; name: string };
  };
}
