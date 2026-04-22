'use client';

import { useState, Suspense } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useSearchParams } from 'next/navigation';
import { MoreHorizontal, CheckCircle, XCircle, Image as ImageIcon } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Card, CardContent } from '@/components/ui/card';
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
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { DataTable, Column } from '@/components/data-table';
import { api } from '@/lib/api';
import { Subscription, PendingPayment } from '@/lib/types';
import { toast } from 'sonner';
import { format } from 'date-fns';

const STATUS_COLORS: Record<string, string> = {
  active: 'bg-green-100 text-green-700',
  trial: 'bg-blue-100 text-blue-700',
  pending: 'bg-yellow-100 text-yellow-700',
  expired: 'bg-red-100 text-red-700',
  cancelled: 'bg-gray-100 text-gray-600',
};

const STATUS_LABELS: Record<string, string> = {
  active: 'Активна',
  trial: 'Trial',
  pending: 'Ожидает',
  expired: 'Истекла',
  cancelled: 'Отменена',
};

export default function SubscriptionsPage() {
  return (
    <Suspense fallback={<div className="h-8 w-32 animate-pulse rounded bg-slate-100" />}>
      <SubscriptionsContent />
    </Suspense>
  );
}

function SubscriptionsContent() {
  const searchParams = useSearchParams();
  const defaultTab = searchParams.get('tab') === 'pending' ? 'pending' : 'all';
  const queryClient = useQueryClient();

  // Dialogs
  const [extendDialog, setExtendDialog] = useState<Subscription | null>(null);
  const [discountDialog, setDiscountDialog] = useState<Subscription | null>(null);
  const [rejectDialog, setRejectDialog] = useState<PendingPayment | null>(null);
  const [receiptPreview, setReceiptPreview] = useState<string | null>(null);
  const [extendDays, setExtendDays] = useState('30');
  const [discount, setDiscount] = useState('');
  const [rejectReason, setRejectReason] = useState('');
  const [changePlanStore, setChangePlanStore] = useState<Subscription | null>(null);
  const [newPlan, setNewPlan] = useState('');

  const { data: subscriptions = [], isLoading: subLoading } = useQuery<Subscription[]>({
    queryKey: ['subscriptions'],
    queryFn: () => api.get('/admin/subscriptions'),
  });

  const { data: pendingPayments = [], isLoading: pendingLoading } = useQuery<PendingPayment[]>({
    queryKey: ['pending-payments'],
    queryFn: () => api.get('/admin/subscriptions/pending'),
  });

  const extendMutation = useMutation({
    mutationFn: ({ id, days }: { id: string; days: number }) =>
      api.put(`/admin/subscriptions/${id}/extend`, { days }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['subscriptions'] });
      setExtendDialog(null);
      toast.success('Подписка продлена');
    },
    onError: () => toast.error('Ошибка продления'),
  });

  const changePlanMutation = useMutation({
    mutationFn: ({ id, planId }: { id: string; planId: string }) =>
      api.put(`/admin/subscriptions/${id}/change-plan`, { planId }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['subscriptions'] });
      setChangePlanStore(null);
      toast.success('Тариф изменён');
    },
    onError: () => toast.error('Ошибка изменения тарифа'),
  });

  const discountMutation = useMutation({
    mutationFn: ({ id, discount }: { id: string; discount: number }) =>
      api.put(`/admin/subscriptions/${id}/discount`, { discount }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['subscriptions'] });
      setDiscountDialog(null);
      toast.success('Скидка установлена');
    },
    onError: () => toast.error('Ошибка установки скидки'),
  });

  const cancelMutation = useMutation({
    mutationFn: (id: string) => api.put(`/admin/subscriptions/${id}/cancel`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['subscriptions'] });
      toast.success('Подписка отменена');
    },
    onError: () => toast.error('Ошибка отмены'),
  });

  const approveMutation = useMutation({
    mutationFn: (id: string) => api.put(`/admin/subscriptions/payments/${id}/approve`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pending-payments'] });
      queryClient.invalidateQueries({ queryKey: ['subscriptions'] });
      toast.success('Платёж подтверждён');
    },
    onError: () => toast.error('Ошибка подтверждения'),
  });

  const rejectMutation = useMutation({
    mutationFn: ({ id, reason }: { id: string; reason: string }) =>
      api.put(`/admin/subscriptions/payments/${id}/reject`, { reason }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pending-payments'] });
      setRejectDialog(null);
      setRejectReason('');
      toast.success('Платёж отклонён');
    },
    onError: () => toast.error('Ошибка отклонения'),
  });

  const columns: Column<Subscription>[] = [
    {
      key: 'store',
      header: 'Магазин',
      cell: (s) => <span className="font-medium">{s.storeName}</span>,
    },
    {
      key: 'plan',
      header: 'Тариф',
      cell: (s) => <span className="text-sm">{s.planName}</span>,
    },
    {
      key: 'status',
      header: 'Статус',
      cell: (s) => (
        <Badge className={`${STATUS_COLORS[s.status] || ''} hover:opacity-80`}>
          {STATUS_LABELS[s.status] || s.status}
        </Badge>
      ),
    },
    {
      key: 'expires',
      header: 'Истекает',
      cell: (s) => (
        <span className="text-sm text-muted-foreground">
          {s.expiresAt ? format(new Date(s.expiresAt), 'dd.MM.yyyy') : '—'}
        </span>
      ),
    },
    {
      key: 'discount',
      header: 'Скидка',
      cell: (s) => (
        <span className="text-sm">{s.discount ? `${s.discount}%` : '—'}</span>
      ),
    },
    {
      key: 'actions',
      header: '',
      cell: (s) => (
        <DropdownMenu>
          <DropdownMenuTrigger className="inline-flex h-7 w-7 items-center justify-center rounded hover:bg-muted">
            <MoreHorizontal className="h-4 w-4" />
          </DropdownMenuTrigger>
          <DropdownMenuContent align="end">
            <DropdownMenuItem onClick={() => { setExtendDialog(s); setExtendDays('30'); }}>
              Продлить
            </DropdownMenuItem>
            <DropdownMenuItem onClick={() => { setChangePlanStore(s); setNewPlan(''); }}>
              Изменить тариф
            </DropdownMenuItem>
            <DropdownMenuItem onClick={() => { setDiscountDialog(s); setDiscount(String(s.discount || '')); }}>
              Установить скидку
            </DropdownMenuItem>
            <DropdownMenuItem
              className="text-red-600"
              onClick={() => cancelMutation.mutate(s.id)}
            >
              Отменить
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
        <h1 className="text-2xl font-semibold">Подписки</h1>
        <p className="text-muted-foreground text-sm mt-1">
          Управление подписками и платежами
        </p>
      </div>

      <Tabs defaultValue={defaultTab}>
        <TabsList>
          <TabsTrigger value="all">
            Все подписки ({subscriptions.length})
          </TabsTrigger>
          <TabsTrigger value="pending">
            Ожидают оплаты ({pendingPayments.length})
            {pendingPayments.length > 0 && (
              <span className="ml-1 flex h-4 w-4 items-center justify-center rounded-full bg-yellow-500 text-[10px] font-bold text-white">
                {pendingPayments.length}
              </span>
            )}
          </TabsTrigger>
        </TabsList>

        <TabsContent value="all" className="mt-4">
          <DataTable
            data={subscriptions}
            columns={columns}
            isLoading={subLoading}
            emptyMessage="Подписки не найдены"
          />
        </TabsContent>

        <TabsContent value="pending" className="mt-4">
          {pendingLoading ? (
            <div className="grid grid-cols-2 gap-4">
              {[1, 2].map((i) => (
                <div key={i} className="h-32 animate-pulse rounded bg-slate-100" />
              ))}
            </div>
          ) : pendingPayments.length === 0 ? (
            <div className="text-center py-12 text-muted-foreground">
              Нет ожидающих платежей
            </div>
          ) : (
            <div className="grid grid-cols-2 gap-4">
              {pendingPayments.map((p) => (
                <Card key={p.id}>
                  <CardContent className="pt-4 space-y-3">
                    <div className="flex items-start justify-between">
                      <div>
                        <p className="font-medium">{p.storeName}</p>
                        <p className="text-sm text-muted-foreground">{p.planName}</p>
                        <p className="font-semibold text-lg mt-1">
                          {new Intl.NumberFormat('ru-TJ', {
                            style: 'currency',
                            currency: 'TJS',
                            maximumFractionDigits: 0,
                          }).format(p.amount)}
                        </p>
                      </div>
                      {p.receiptUrl && (
                        <button
                          onClick={() => setReceiptPreview(p.receiptUrl!)}
                          className="flex h-16 w-16 items-center justify-center rounded border bg-slate-50 hover:bg-slate-100 transition-colors"
                        >
                          <ImageIcon className="h-6 w-6 text-muted-foreground" />
                        </button>
                      )}
                    </div>
                    <p className="text-xs text-muted-foreground">
                      {p.createdAt ? format(new Date(p.createdAt), 'dd.MM.yyyy HH:mm') : '—'}
                    </p>
                    <div className="flex gap-2">
                      <Button
                        size="sm"
                        className="flex-1 bg-green-600 hover:bg-green-700 text-white"
                        onClick={() => approveMutation.mutate(p.id)}
                        disabled={approveMutation.isPending}
                      >
                        <CheckCircle className="mr-1 h-3 w-3" />
                        Подтвердить
                      </Button>
                      <Button
                        size="sm"
                        variant="destructive"
                        className="flex-1"
                        onClick={() => setRejectDialog(p)}
                      >
                        <XCircle className="mr-1 h-3 w-3" />
                        Отклонить
                      </Button>
                    </div>
                  </CardContent>
                </Card>
              ))}
            </div>
          )}
        </TabsContent>
      </Tabs>

      {/* Extend Dialog */}
      <Dialog open={!!extendDialog} onOpenChange={() => setExtendDialog(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Продлить подписку</DialogTitle>
          </DialogHeader>
          <div className="space-y-3 py-2">
            <p className="text-sm text-muted-foreground">
              Магазин: <strong>{extendDialog?.storeName}</strong>
            </p>
            <div className="space-y-2">
              <Label>Количество дней</Label>
              <Input
                type="number"
                min="1"
                value={extendDays}
                onChange={(e) => setExtendDays(e.target.value)}
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setExtendDialog(null)}>
              Отмена
            </Button>
            <Button
              onClick={() =>
                extendDialog &&
                extendMutation.mutate({ id: extendDialog.id, days: Number(extendDays) })
              }
              disabled={extendMutation.isPending}
            >
              Продлить
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Change Plan Dialog */}
      <Dialog open={!!changePlanStore} onOpenChange={() => setChangePlanStore(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Изменить тариф</DialogTitle>
          </DialogHeader>
          <div className="space-y-3 py-2">
            <p className="text-sm text-muted-foreground">
              Магазин: <strong>{changePlanStore?.storeName}</strong>
            </p>
            <div className="space-y-2">
              <Label>Новый тариф</Label>
              <Select value={newPlan} onValueChange={(v) => v != null && setNewPlan(v)}>
                <SelectTrigger>
                  <SelectValue placeholder="Выберите тариф" />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="START">START</SelectItem>
                  <SelectItem value="BUSINESS">BUSINESS</SelectItem>
                  <SelectItem value="PREMIUM">PREMIUM</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setChangePlanStore(null)}>
              Отмена
            </Button>
            <Button
              onClick={() =>
                changePlanStore &&
                changePlanMutation.mutate({ id: changePlanStore.id, planId: newPlan })
              }
              disabled={!newPlan || changePlanMutation.isPending}
            >
              Изменить
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Discount Dialog */}
      <Dialog open={!!discountDialog} onOpenChange={() => setDiscountDialog(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Установить скидку</DialogTitle>
          </DialogHeader>
          <div className="space-y-3 py-2">
            <p className="text-sm text-muted-foreground">
              Магазин: <strong>{discountDialog?.storeName}</strong>
            </p>
            <div className="space-y-2">
              <Label>Скидка (0–100%)</Label>
              <Input
                type="number"
                min="0"
                max="100"
                value={discount}
                onChange={(e) => setDiscount(e.target.value)}
                placeholder="Например: 20"
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setDiscountDialog(null)}>
              Отмена
            </Button>
            <Button
              onClick={() =>
                discountDialog &&
                discountMutation.mutate({ id: discountDialog.id, discount: Number(discount) })
              }
              disabled={discount === '' || discountMutation.isPending}
            >
              Сохранить
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Reject Dialog */}
      <Dialog open={!!rejectDialog} onOpenChange={() => setRejectDialog(null)}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Отклонить платёж</DialogTitle>
          </DialogHeader>
          <div className="space-y-3 py-2">
            <p className="text-sm text-muted-foreground">
              Магазин: <strong>{rejectDialog?.storeName}</strong>
            </p>
            <div className="space-y-2">
              <Label>Причина отклонения</Label>
              <Textarea
                value={rejectReason}
                onChange={(e) => setRejectReason(e.target.value)}
                placeholder="Укажите причину..."
                rows={3}
              />
            </div>
          </div>
          <DialogFooter>
            <Button variant="outline" onClick={() => setRejectDialog(null)}>
              Отмена
            </Button>
            <Button
              variant="destructive"
              onClick={() =>
                rejectDialog &&
                rejectMutation.mutate({ id: rejectDialog.id, reason: rejectReason })
              }
              disabled={rejectMutation.isPending}
            >
              Отклонить
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>

      {/* Receipt Preview */}
      <Dialog open={!!receiptPreview} onOpenChange={() => setReceiptPreview(null)}>
        <DialogContent className="max-w-2xl">
          <DialogHeader>
            <DialogTitle>Чек об оплате</DialogTitle>
          </DialogHeader>
          {receiptPreview && (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={receiptPreview}
              alt="Чек об оплате"
              className="w-full rounded"
            />
          )}
        </DialogContent>
      </Dialog>
    </div>
  );
}
