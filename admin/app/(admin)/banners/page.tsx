'use client';

import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Send } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Textarea } from '@/components/ui/textarea';
import { Switch } from '@/components/ui/switch';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { Badge } from '@/components/ui/badge';
import { api } from '@/lib/api';
import { Banner } from '@/lib/types';
import { toast } from 'sonner';
import { format } from 'date-fns';

export default function BannersPage() {
  const queryClient = useQueryClient();
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [targetPlan, setTargetPlan] = useState('all');
  const [targetStatus, setTargetStatus] = useState('all');
  const [startDate, setStartDate] = useState('');
  const [endDate, setEndDate] = useState('');

  const { data: banners = [], isLoading } = useQuery<Banner[]>({
    queryKey: ['banners'],
    queryFn: () => api.get('/admin/banners').then((r) => r.data ?? r ?? []),
  });

  const createMutation = useMutation({
    mutationFn: () =>
      api.post('/admin/banners', {
        title,
        body,
        targetPlan: targetPlan === 'all' ? undefined : targetPlan,
        targetStatus: targetStatus === 'all' ? undefined : targetStatus,
        startDate,
        endDate,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['banners'] });
      setTitle('');
      setBody('');
      setTargetPlan('all');
      setTargetStatus('all');
      setStartDate('');
      setEndDate('');
      toast.success('Баннер создан');
    },
    onError: () => toast.error('Ошибка создания баннера'),
  });

  const toggleActiveMutation = useMutation({
    mutationFn: ({ id, active }: { id: string; active: boolean }) =>
      api.put(`/admin/banners/${id}/active`, { active }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['banners'] });
    },
    onError: () => toast.error('Ошибка изменения статуса баннера'),
  });

  const handleCreate = () => {
    if (!title.trim() || !body.trim()) {
      toast.error('Заполните заголовок и текст баннера');
      return;
    }
    if (!startDate || !endDate) {
      toast.error('Укажите период показа баннера');
      return;
    }
    createMutation.mutate();
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold">Баннеры</h1>
        <p className="text-muted-foreground text-sm mt-1">
          Внутриприложенные баннеры для пользователей
        </p>
      </div>

      {/* Compose Form */}
      <Card>
        <CardHeader>
          <CardTitle className="text-base">Новый баннер</CardTitle>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <Label>Заголовок</Label>
            <Input
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              placeholder="Например: Скидка на PREMIUM"
              maxLength={200}
            />
          </div>

          <div className="space-y-2">
            <Label>Текст баннера</Label>
            <Textarea
              value={body}
              onChange={(e) => setBody(e.target.value)}
              placeholder="Введите текст баннера..."
              rows={4}
            />
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label>Фильтр по тарифу</Label>
              <Select value={targetPlan} onValueChange={(v) => v != null && setTargetPlan(v)}>
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Все тарифы</SelectItem>
                  <SelectItem value="START">START</SelectItem>
                  <SelectItem value="BUSINESS">BUSINESS</SelectItem>
                  <SelectItem value="PREMIUM">PREMIUM</SelectItem>
                </SelectContent>
              </Select>
            </div>
            <div className="space-y-2">
              <Label>Фильтр по статусу</Label>
              <Select
                value={targetStatus}
                onValueChange={(v) => v != null && setTargetStatus(v)}
              >
                <SelectTrigger>
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="all">Все статусы</SelectItem>
                  <SelectItem value="TRIAL">Trial</SelectItem>
                  <SelectItem value="ACTIVE">Активные</SelectItem>
                  <SelectItem value="PAST_DUE">Просрочены</SelectItem>
                  <SelectItem value="CANCELLED">Отменены</SelectItem>
                  <SelectItem value="EXPIRED">Истекшие</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label>Дата начала</Label>
              <Input
                type="date"
                value={startDate}
                onChange={(e) => setStartDate(e.target.value)}
              />
            </div>
            <div className="space-y-2">
              <Label>Дата окончания</Label>
              <Input
                type="date"
                value={endDate}
                onChange={(e) => setEndDate(e.target.value)}
              />
            </div>
          </div>

          <Button
            onClick={handleCreate}
            disabled={
              !title.trim() || !body.trim() || !startDate || !endDate || createMutation.isPending
            }
          >
            <Send className="mr-2 h-4 w-4" />
            Создать баннер
          </Button>
        </CardContent>
      </Card>

      {/* List */}
      <div>
        <h2 className="font-semibold mb-3">Все баннеры</h2>
        <div className="rounded-md border">
          <Table>
            <TableHeader>
              <TableRow>
                <TableHead>Заголовок</TableHead>
                <TableHead>Аудитория</TableHead>
                <TableHead>Период показа</TableHead>
                <TableHead>Создан</TableHead>
                <TableHead>Активен</TableHead>
              </TableRow>
            </TableHeader>
            <TableBody>
              {isLoading ? (
                Array.from({ length: 3 }).map((_, i) => (
                  <TableRow key={i}>
                    {Array.from({ length: 5 }).map((__, j) => (
                      <TableCell key={j}>
                        <div className="h-4 animate-pulse rounded bg-slate-100" />
                      </TableCell>
                    ))}
                  </TableRow>
                ))
              ) : banners.length === 0 ? (
                <TableRow>
                  <TableCell colSpan={5} className="h-24 text-center text-muted-foreground">
                    Нет баннеров
                  </TableCell>
                </TableRow>
              ) : (
                banners.map((b) => (
                  <TableRow key={b.id}>
                    <TableCell className="font-medium max-w-xs truncate">{b.title}</TableCell>
                    <TableCell>
                      <div className="flex gap-1 flex-wrap">
                        {b.targetPlan && (
                          <Badge variant="outline" className="text-xs">
                            {b.targetPlan}
                          </Badge>
                        )}
                        {b.targetStatus && (
                          <Badge variant="outline" className="text-xs">
                            {b.targetStatus}
                          </Badge>
                        )}
                        {!b.targetPlan && !b.targetStatus && (
                          <span className="text-sm text-muted-foreground">Все</span>
                        )}
                      </div>
                    </TableCell>
                    <TableCell className="text-sm text-muted-foreground">
                      {format(new Date(b.startDate), 'dd.MM.yyyy')} —{' '}
                      {format(new Date(b.endDate), 'dd.MM.yyyy')}
                    </TableCell>
                    <TableCell className="text-sm text-muted-foreground">
                      {b.createdAt ? format(new Date(b.createdAt), 'dd.MM.yyyy HH:mm') : '—'}
                    </TableCell>
                    <TableCell>
                      <Switch
                        checked={b.active}
                        onCheckedChange={(checked) =>
                          toggleActiveMutation.mutate({ id: b.id, active: checked })
                        }
                      />
                    </TableCell>
                  </TableRow>
                ))
              )}
            </TableBody>
          </Table>
        </div>
      </div>
    </div>
  );
}
