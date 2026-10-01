'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useRouter } from 'next/navigation';
import { MoreHorizontal, Search, Download, Plus } from 'lucide-react';
import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogFooter,
} from '@/components/ui/dialog';
import { Label } from '@/components/ui/label';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { DataTable, Column } from '@/components/data-table';
import { ConfirmDialog } from '@/components/confirm-dialog';
import { UserPicker } from '@/components/user-picker';
import { api } from '@/lib/api';
import { Store } from '@/lib/types';
import { toast } from 'sonner';

const PLAN_COLORS: Record<string, string> = {
  START: 'bg-gray-100 text-gray-700',
  BUSINESS: 'bg-blue-100 text-blue-700',
  PREMIUM: 'bg-purple-100 text-purple-700',
};

const SUB_STATUS_COLORS: Record<string, string> = {
  ACTIVE: 'bg-green-100 text-green-700',
  TRIAL: 'bg-blue-100 text-blue-700',
  PAST_DUE: 'bg-yellow-100 text-yellow-700',
  CANCELED: 'bg-gray-100 text-gray-600',
  EXPIRED: 'bg-red-100 text-red-700',
};

const SUB_STATUS_LABELS: Record<string, string> = {
  ACTIVE: 'Активна',
  TRIAL: 'Trial',
  PAST_DUE: 'Просрочена',
  CANCELED: 'Отменена',
  EXPIRED: 'Истекла',
};

// Statuses the on-screen filter supports that the export endpoint cannot
// express as a query param (AdminStoresQueryDto only supports `isActive`,
// not subscription status). SUSPENDED is excluded here because it maps
// onto `isActive=false` directly.
const UNSUPPORTED_EXPORT_STATUSES = new Set(['ACTIVE', 'TRIAL', 'PAST_DUE', 'EXPIRED']);

// Mirrors STORE_CATEGORIES in api/src/modules/admin/dto/create-store-by-admin.dto.ts —
// the backend @IsEnum rejects anything else.
const STORE_CATEGORIES: { value: string; label: string }[] = [
  { value: 'GROCERY', label: 'Продукты' },
  { value: 'CLOTHING', label: 'Одежда' },
  { value: 'ELECTRONICS', label: 'Электроника' },
  { value: 'HARDWARE', label: 'Хозтовары' },
  { value: 'PHARMACY', label: 'Аптека' },
  { value: 'OTHER', label: 'Другое' },
];

const EMPTY_NEW_STORE = {
  ownerId: '',
  name: '',
  category: 'GROCERY',
  currency: 'TJS',
  address: '',
  phone: '',
};

export default function StoresPage() {
  const router = useRouter();
  const queryClient = useQueryClient();
  const [search, setSearch] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('all');
  const [planFilter, setPlanFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [transferDialog, setTransferDialog] = useState<Store | null>(null);
  const [newOwnerId, setNewOwnerId] = useState('');
  const [suspendConfirm, setSuspendConfirm] = useState<Store | null>(null);
  const [createOpen, setCreateOpen] = useState(false);
  const [newStore, setNewStore] = useState(EMPTY_NEW_STORE);
  const [createError, setCreateError] = useState<string | null>(null);

  const { data: stores = [], isLoading } = useQuery<Store[]>({
    queryKey: ['stores'],
    // limit=1000: same reasoning as the Users page's identical fix — this
    // page has no pagination UI, so a hidden backend default of 20 was
    // silently dropping stores past the first page from every client-side
    // filter/search on this list.
    queryFn: () => api.get('/admin/stores?limit=1000').then((r) => r.data ?? []),
  });

  const suspendMutation = useMutation({
    mutationFn: (store: Store) =>
      api.put(`/admin/stores/${store.id}/${!store.isActive ? 'unsuspend' : 'suspend'}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['stores'] });
      setSuspendConfirm(null);
      toast.success('Статус магазина обновлён');
    },
    onError: () => toast.error('Ошибка обновления статуса'),
  });

  const transferMutation = useMutation({
    mutationFn: ({ storeId, newOwnerId }: { storeId: string; newOwnerId: string }) =>
      api.put(`/admin/stores/${storeId}/transfer`, { newOwnerId }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['stores'] });
      setTransferDialog(null);
      setNewOwnerId('');
      toast.success('Владелец магазина изменён');
    },
    onError: () => toast.error('Ошибка передачи магазина'),
  });

  const createMutation = useMutation({
    mutationFn: (body: typeof EMPTY_NEW_STORE) =>
      api.post('/admin/stores', {
        ownerId: body.ownerId,
        name: body.name,
        category: body.category,
        currency: body.currency,
        address: body.address || undefined,
        phone: body.phone || undefined,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['stores'] });
      setCreateOpen(false);
      setCreateError(null);
      setNewStore(EMPTY_NEW_STORE);
      toast.success('Магазин создан');
    },
    onError: (e: unknown) => {
      // Surface the server's message inline — an unknown owner or a rejected
      // field is a recoverable mistake the admin should still see while
      // fixing it, not only in a toast that fades.
      //
      // lib/api.ts is a fetch wrapper, not axios: it throws
      // `new Error(data.message || 'HTTP <status>')`, so the message lives on
      // `.message`. There is no `e.response.data.message`.
      setCreateError(e instanceof Error ? e.message : 'Не удалось создать магазин');
      toast.error('Ошибка создания магазина');
    },
  });

  const categories = ['all', ...new Set(stores.map((s) => s.category).filter(Boolean) as string[])];

  const filtered = stores.filter((s) => {
    const matchesSearch =
      !search ||
      s.name.toLowerCase().includes(search.toLowerCase()) ||
      s.owner?.name?.toLowerCase().includes(search.toLowerCase());
    const matchesCategory = categoryFilter === 'all' || s.category === categoryFilter;
    const matchesPlan = planFilter === 'all' || s.subscription?.plan === planFilter;
    const subStatus = s.isActive ? s.subscription?.status ?? 'EXPIRED' : 'SUSPENDED';
    const matchesStatus = statusFilter === 'all' || subStatus === statusFilter;
    return matchesSearch && matchesCategory && matchesPlan && matchesStatus;
  });

  const columns: Column<Store>[] = [
    {
      key: 'name',
      header: 'Название',
      cell: (s) => <span className="font-medium">{s.name}</span>,
    },
    {
      key: 'owner',
      header: 'Владелец',
      cell: (s) => <span className="text-sm">{s.owner?.name || '—'}</span>,
    },
    {
      key: 'category',
      header: 'Категория',
      cell: (s) => <span className="text-sm">{s.category || '—'}</span>,
    },
    {
      key: 'plan',
      header: 'Тариф',
      cell: (s) => s.subscription?.plan ? (
        <Badge className={`${PLAN_COLORS[s.subscription.plan] || 'bg-gray-100 text-gray-700'} hover:opacity-80`}>
          {s.subscription.plan}
        </Badge>
      ) : <span>—</span>,
    },
    {
      key: 'status',
      header: 'Статус',
      cell: (s) => {
        if (!s.isActive) {
          return (
            <Badge className="bg-red-100 text-red-700 hover:opacity-80">
              Приостановлен
            </Badge>
          );
        }
        const subStatus = s.subscription?.status ?? 'EXPIRED';
        return (
          <Badge className={`${SUB_STATUS_COLORS[subStatus] || ''} hover:opacity-80`}>
            {SUB_STATUS_LABELS[subStatus] || subStatus}
          </Badge>
        );
      },
    },
    {
      key: 'products',
      header: 'Товары',
      cell: (s) => <span className="text-sm">{s._count?.products ?? 0}</span>,
    },
    {
      key: 'sales',
      header: 'Продаж/мес',
      cell: (s) => <span className="text-sm">{s.monthlySalesCount ?? 0}</span>,
    },
    {
      key: 'actions',
      header: '',
      cell: (s) => (
        <DropdownMenu>
          <DropdownMenuTrigger
            onClick={(e) => e.stopPropagation()}
            className="inline-flex h-7 w-7 items-center justify-center rounded hover:bg-muted"
          >
            <MoreHorizontal className="h-4 w-4" />
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem
              onClick={(e) => {
                e.stopPropagation();
                if (s.isActive) {
                  setSuspendConfirm(s);
                } else {
                  suspendMutation.mutate(s);
                }
              }}
              className={!s.isActive ? 'text-green-600' : 'text-red-600'}
            >
              {!s.isActive ? 'Восстановить' : 'Приостановить'}
            </DropdownMenuItem>
            <DropdownMenuItem
              onClick={(e) => {
                e.stopPropagation();
                setTransferDialog(s);
              }}
            >
              Передать владение
            </DropdownMenuItem>
          </DropdownMenuContent>
        </DropdownMenu>
      ),
      className: 'w-12',
    },
  ];

  return (
    <div className="space-y-4">
      <div className="flex items-start justify-between gap-3">
        <div>
          <h1 className="text-2xl font-semibold">Магазины</h1>
          <p className="text-muted-foreground text-sm mt-1">
            {stores.length} магазинов всего
          </p>
        </div>
        <Button onClick={() => setCreateOpen(true)}>
          <Plus className="mr-2 h-4 w-4" />
          Создать магазин
        </Button>
      </div>

      <div className="flex flex-wrap items-center gap-3">
        <div className="relative flex-1 min-w-48">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
          <Input
            placeholder="Поиск по названию, владельцу..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="pl-9"
          />
        </div>
        <Select value={categoryFilter} onValueChange={(v) => v != null && setCategoryFilter(v)}>
          <SelectTrigger className="w-40">
            <SelectValue placeholder="Категория" />
          </SelectTrigger>
          <SelectContent>
            {categories.map((c) => (
              <SelectItem key={c} value={c}>
                {c === 'all' ? 'Все категории' : c}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
        <Select value={planFilter} onValueChange={(v) => v != null && setPlanFilter(v)}>
          <SelectTrigger className="w-36">
            <SelectValue placeholder="Тариф" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">Все тарифы</SelectItem>
            <SelectItem value="START">START</SelectItem>
            <SelectItem value="BUSINESS">BUSINESS</SelectItem>
            <SelectItem value="PREMIUM">PREMIUM</SelectItem>
          </SelectContent>
        </Select>
        <Select value={statusFilter} onValueChange={(v) => v != null && setStatusFilter(v)}>
          <SelectTrigger className="w-40">
            <SelectValue placeholder="Статус" />
          </SelectTrigger>
          <SelectContent>
            <SelectItem value="all">Все статусы</SelectItem>
            <SelectItem value="ACTIVE">Активна</SelectItem>
            <SelectItem value="TRIAL">Trial</SelectItem>
            <SelectItem value="PAST_DUE">Просрочена</SelectItem>
            <SelectItem value="SUSPENDED">Приостановлен</SelectItem>
            <SelectItem value="EXPIRED">Истекла</SelectItem>
          </SelectContent>
        </Select>
        <Button
          variant="outline"
          onClick={() => {
            const params = new URLSearchParams();
            if (search) params.set('search', search);
            if (categoryFilter !== 'all') params.set('category', categoryFilter);
            if (planFilter !== 'all') params.set('plan', planFilter);
            // The admin list DTO only supports filtering by isActive, not by
            // subscription status — SUSPENDED is the one statusFilter value
            // that maps onto it directly. The remaining subscription-status
            // values (ACTIVE/TRIAL/PAST_DUE/EXPIRED) can't be expressed as an
            // export query param, so warn the admin their export will include
            // stores outside the on-screen filter instead of silently
            // returning a mismatched file.
            if (UNSUPPORTED_EXPORT_STATUSES.has(statusFilter)) {
              toast.warning(
                'Экспорт по статусу подписки пока не поддерживается — будут выгружены все магазины',
              );
            } else if (statusFilter === 'SUSPENDED') {
              params.set('isActive', 'false');
            }
            window.location.href = `/api/proxy/admin/stores/export?${params.toString()}`;
          }}
        >
          <Download className="mr-2 h-4 w-4" />
          Экспорт
        </Button>
      </div>

      <DataTable
        data={filtered}
        columns={columns}
        isLoading={isLoading}
        onRowClick={(s) => router.push(`/stores/${s.id}`)}
        emptyMessage="Магазины не найдены"
      />

      <ConfirmDialog
        open={!!suspendConfirm}
        onOpenChange={(open) => !open && setSuspendConfirm(null)}
        title="Приостановить магазин?"
        description={`Магазин «${suspendConfirm?.name}» станет недоступен владельцу до восстановления.`}
        confirmLabel="Приостановить"
        variant="destructive"
        pending={suspendMutation.isPending}
        onConfirm={() => {
          if (suspendConfirm) suspendMutation.mutate(suspendConfirm);
        }}
      />

      {/* Create-store dialog */}
      <Dialog
        open={createOpen}
        onOpenChange={(open) => {
          setCreateOpen(open);
          if (!open) setCreateError(null);
        }}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Создать магазин</DialogTitle>
          </DialogHeader>
          <div className="space-y-3 py-2">
            <div className="space-y-2">
              {/* UserPicker owns its own search Input and does not forward an
                  id, so this Label is descriptive rather than associated —
                  same as the transfer dialog's. */}
              <Label>Владелец</Label>
              <UserPicker
                key={createOpen ? 'create-open' : 'create-closed'}
                value={newStore.ownerId}
                onSelect={(id) => setNewStore((s) => ({ ...s, ownerId: id }))}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="create-name">Название</Label>
              <Input
                id="create-name"
                value={newStore.name}
                onChange={(e) => setNewStore((s) => ({ ...s, name: e.target.value }))}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="create-category">Категория</Label>
              <select
                id="create-category"
                className="w-full rounded-md border px-3 py-2 text-sm"
                value={newStore.category}
                onChange={(e) => setNewStore((s) => ({ ...s, category: e.target.value }))}
              >
                {STORE_CATEGORIES.map((c) => (
                  <option key={c.value} value={c.value}>
                    {c.label}
                  </option>
                ))}
              </select>
            </div>
            <div className="space-y-2">
              <Label htmlFor="create-currency">Валюта</Label>
              <select
                id="create-currency"
                className="w-full rounded-md border px-3 py-2 text-sm"
                value={newStore.currency}
                onChange={(e) => setNewStore((s) => ({ ...s, currency: e.target.value }))}
              >
                <option value="TJS">TJS</option>
                <option value="USD">USD</option>
                <option value="RUB">RUB</option>
              </select>
            </div>
            <div className="space-y-2">
              <Label htmlFor="create-address">Адрес</Label>
              <Input
                id="create-address"
                value={newStore.address}
                onChange={(e) => setNewStore((s) => ({ ...s, address: e.target.value }))}
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="create-phone">Телефон</Label>
              <Input
                id="create-phone"
                placeholder="+992901234567"
                value={newStore.phone}
                onChange={(e) => setNewStore((s) => ({ ...s, phone: e.target.value }))}
              />
            </div>
            {createError && <p className="text-sm text-destructive">{createError}</p>}
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setCreateOpen(false)}>
              Отмена
            </Button>
            <Button
              onClick={() => createMutation.mutate(newStore)}
              disabled={!newStore.ownerId || !newStore.name || createMutation.isPending}
            >
              Создать
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Transfer dialog */}
      <Dialog
        open={!!transferDialog}
        onOpenChange={() => {
          setTransferDialog(null);
          setNewOwnerId('');
        }}
      >
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Передать магазин</DialogTitle>
          </DialogHeader>
          <div className="space-y-3 py-2">
            <p className="text-sm text-muted-foreground">
              Магазин: <strong>{transferDialog?.name}</strong>
            </p>
            <div className="space-y-2">
              <Label>Новый владелец</Label>
              <UserPicker key={transferDialog?.id} value={newOwnerId} onSelect={(id) => setNewOwnerId(id)} />
            </div>
          </div>
          <DialogFooter>
            <Button
              variant="outline"
              onClick={() => {
                setTransferDialog(null);
                setNewOwnerId('');
              }}
            >
              Отмена
            </Button>
            <Button
              onClick={() =>
                transferDialog &&
                transferMutation.mutate({
                  storeId: transferDialog.id,
                  newOwnerId,
                })
              }
              disabled={!newOwnerId || transferMutation.isPending}
            >
              Передать
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
