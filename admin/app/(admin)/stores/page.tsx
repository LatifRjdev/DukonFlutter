'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useRouter } from 'next/navigation';
import { MoreHorizontal, Search, Download } from 'lucide-react';
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

export default function StoresPage() {
  const router = useRouter();
  const queryClient = useQueryClient();
  const [search, setSearch] = useState('');
  const [categoryFilter, setCategoryFilter] = useState('all');
  const [planFilter, setPlanFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');
  const [transferDialog, setTransferDialog] = useState<Store | null>(null);
  const [newOwnerId, setNewOwnerId] = useState('');

  const { data: stores = [], isLoading } = useQuery<Store[]>({
    queryKey: ['stores'],
    queryFn: () => api.get('/admin/stores').then((r) => r.data ?? []),
  });

  const suspendMutation = useMutation({
    mutationFn: (store: Store) =>
      api.put(`/admin/stores/${store.id}/${!store.isActive ? 'unsuspend' : 'suspend'}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['stores'] });
      toast.success('Статус магазина обновлён');
    },
    onError: () => toast.error('Ошибка обновления статуса'),
  });

  const transferMutation = useMutation({
    mutationFn: ({ storeId, userId }: { storeId: string; userId: string }) =>
      api.put(`/admin/stores/${storeId}/transfer`, { userId }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['stores'] });
      setTransferDialog(null);
      setNewOwnerId('');
      toast.success('Владелец магазина изменён');
    },
    onError: () => toast.error('Ошибка передачи магазина'),
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
                suspendMutation.mutate(s);
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
      <div>
        <h1 className="text-2xl font-semibold">Магазины</h1>
        <p className="text-muted-foreground text-sm mt-1">
          {stores.length} магазинов всего
        </p>
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
            // that maps onto it directly.
            if (statusFilter === 'SUSPENDED') params.set('isActive', 'false');
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

      {/* Transfer dialog */}
      <Dialog open={!!transferDialog} onOpenChange={() => setTransferDialog(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Передать магазин</DialogTitle>
          </DialogHeader>
          <div className="space-y-3 py-2">
            <p className="text-sm text-muted-foreground">
              Магазин: <strong>{transferDialog?.name}</strong>
            </p>
            <div className="space-y-2">
              <Label>ID нового владельца</Label>
              <Input
                value={newOwnerId}
                onChange={(e) => setNewOwnerId(e.target.value)}
                placeholder="Введите ID пользователя"
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setTransferDialog(null)}>
              Отмена
            </Button>
            <Button
              onClick={() =>
                transferDialog &&
                transferMutation.mutate({
                  storeId: transferDialog.id,
                  userId: newOwnerId,
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
