// src/components/frigorifico/FrigorificoDashboard.tsx - VERSIÓN COMPLETA FUNCIONAL
'use client';

import { useState, useEffect } from 'react';
import { useStarknet } from '@/providers/starknet-provider';
import { TransaccionesPendientesTab } from './tabs/TransaccionesPendientesTab';
import { CortesTab } from './tabs/CortesTab';
import { getFrigorificoService } from '@/services/FrigorificoService';

interface FrigorificoStats {
  lotesTransferidos: number;
  lotesProcesados: number;
  animalesProcesados: number;
  cortesCreados: number;
  pesoTotalProcesado: number;
  pesoTotalCortes: number;
}

export function FrigorificoDashboard() {
  const { address, isConnected, contractService } = useStarknet();
  const [activeTab, setActiveTab] = useState<'transacciones' | 'cortes'>('transacciones');
  const [frigorificoService, setFrigorificoService] = useState<any>(null);
  
  const [frigorificoStats, setFrigorificoStats] = useState<FrigorificoStats>({
    lotesTransferidos: 0,
    lotesProcesados: 0,
    animalesProcesados: 0,
    cortesCreados: 0,
    pesoTotalProcesado: 0,
    pesoTotalCortes: 0
  });
  const [lotesPendientes, setLotesPendientes] = useState<any[]>([]);
  const [lotesProcesados, setLotesProcesados] = useState<any[]>([]);
  const [cargando, setCargando] = useState(false);
  const [estado, setEstado] = useState('');
  const [isFrigorifico, setIsFrigorifico] = useState(false);

  // 📥 INICIALIZAR SERVICE
  useEffect(() => {
    if (contractService) {
      const service = getFrigorificoService(contractService);
      setFrigorificoService(service);
    }
  }, [contractService]);

  // 🔍 CARGAR DATOS DEL FRIGORÍFICO
  const cargarDatosFrigorifico = async () => {
    if (!frigorificoService || !address) return;
    
    setCargando(true);
    setEstado('🔄 Cargando datos del frigorífico...');
    
    try {
      // 1. Verificar rol
      const tieneRol = await frigorificoService.verificarRolFrigorifico(address);
      setIsFrigorifico(tieneRol);
      
      if (!tieneRol) {
        setEstado('❌ Sin permisos de frigorífico');
        setCargando(false);
        return;
      }

      // 2. Cargar datos en paralelo
      setEstado('📊 Obteniendo estadísticas y lotes...');
      
      const [stats, pendientes, procesados] = await Promise.all([
        frigorificoService.getFrigorificoStats(address),
        frigorificoService.getLotesPendientes(address),
        frigorificoService.getLotesProcesados(address)
      ]);

      // 3. Actualizar estados
      setFrigorificoStats(stats);
      setLotesPendientes(pendientes);
      setLotesProcesados(procesados);
      
      setEstado(`✅ ${pendientes.length} pendientes, ${procesados.length} procesados, ${stats.cortesCreados} cortes`);
      
    } catch (error: any) {
      console.error('❌ Error cargando datos del frigorífico:', error);
      setEstado(`❌ Error: ${error.message}`);
    } finally {
      setCargando(false);
    }
  };

  // 🔄 RECARGAR DATOS
  const handleRecargar = async () => {
    await cargarDatosFrigorifico();
  };

  // 📥 Cargar datos al conectar
  useEffect(() => {
    if (isConnected && frigorificoService && address) {
      cargarDatosFrigorifico();
    }
  }, [isConnected, frigorificoService, address]);

  if (!isConnected) {
    return (
      <div className="bg-yellow-50 border border-yellow-200 rounded-2xl p-6 text-center">
        <div className="text-4xl mb-4">🔌</div>
        <h3 className="text-xl font-semibold text-yellow-800 mb-2">Wallet No Conectada</h3>
        <p className="text-yellow-700">Conecta tu wallet para acceder al panel del Frigorífico</p>
      </div>
    );
  }

  return (
    <div className="bg-white border border-gray-200 rounded-2xl p-6 shadow-lg">
      <h3 className="text-2xl font-bold text-gray-800 mb-6 flex items-center gap-3">
        <span className="text-3xl">🏭</span>
        Panel del Frigorífico
      </h3>

      {/* Pestañas principales */}
      <div className="flex border-b border-gray-200 mb-6 overflow-x-auto">
        <button
          onClick={() => setActiveTab('transacciones')}
          className={`px-6 py-3 font-semibold border-b-2 transition-colors whitespace-nowrap ${
            activeTab === 'transacciones'
              ? 'border-blue-500 text-blue-600'
              : 'border-transparent text-gray-500 hover:text-gray-700'
          }`}
        >
          🔄 Operaciones Pendientes ({frigorificoStats.lotesTransferidos})
        </button>
        <button
          onClick={() => setActiveTab('cortes')}
          className={`px-6 py-3 font-semibold border-b-2 transition-colors whitespace-nowrap ${
            activeTab === 'cortes'
              ? 'border-blue-500 text-blue-600'
              : 'border-transparent text-gray-500 hover:text-gray-700'
          }`}
        >
          🥩 Crear Cortes ({frigorificoStats.lotesProcesados})
        </button>
      </div>

      {/* Información del frigorífico */}
      <div className="bg-blue-50 border border-blue-200 rounded-xl p-4 mb-6">
        <div className="flex justify-between items-center">
          <div>
            <h4 className="font-semibold text-blue-800 mb-1">
              🏭 Frigorífico {isFrigorifico ? '✅ Verificado' : '❌ No verificado'}
            </h4>
            <p className="text-blue-700 text-sm font-mono">
              {address ? `${address.slice(0, 10)}...${address.slice(-8)}` : 'No conectado'}
            </p>
          </div>
          <div className="text-right">
            <p className="text-blue-700 text-sm">
              <strong>{frigorificoStats.lotesTransferidos}</strong> lotes pendientes
            </p>
            <p className="text-blue-600 text-xs">
              <strong>{frigorificoStats.cortesCreados}</strong> cortes estimados
            </p>
            {!isFrigorifico && (
              <div className="text-red-600 text-sm bg-red-50 px-2 py-1 rounded mt-1">
                ⚠️ Sin permisos de frigorífico
              </div>
            )}
            {cargando && (
              <span className="text-blue-500 text-xs mt-1 flex items-center gap-1">
                <span className="animate-spin rounded-full h-3 w-3 border-b-2 border-blue-500"></span>
                Cargando...
              </span>
            )}
          </div>
        </div>
      </div>

      {/* Estadísticas del Frigorífico - DATOS REALES */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        <div className="bg-orange-50 border border-orange-200 rounded-lg p-3 text-center">
          <div className="text-2xl mb-1">⏳</div>
          <div className="text-lg font-bold text-orange-800">
            {frigorificoStats.lotesTransferidos}
          </div>
          <div className="text-xs text-orange-600">Lotes Pendientes</div>
        </div>
        
        <div className="bg-green-50 border border-green-200 rounded-lg p-3 text-center">
          <div className="text-2xl mb-1">✅</div>
          <div className="text-lg font-bold text-green-800">
            {frigorificoStats.lotesProcesados}
          </div>
          <div className="text-xs text-green-600">Lotes Procesados</div>
        </div>
        
        <div className="bg-blue-50 border border-blue-200 rounded-lg p-3 text-center">
          <div className="text-2xl mb-1">🐄</div>
          <div className="text-lg font-bold text-blue-800">
            {frigorificoStats.animalesProcesados}
          </div>
          <div className="text-xs text-blue-600">Animales Procesados</div>
        </div>
        
        <div className="bg-purple-50 border border-purple-200 rounded-lg p-3 text-center">
          <div className="text-2xl mb-1">🥩</div>
          <div className="text-lg font-bold text-purple-800">
            {frigorificoStats.cortesCreados}
          </div>
          <div className="text-xs text-purple-600">Cortes Estimados</div>
        </div>
      </div>

      {/* Botones de acción */}
      <div className="flex gap-2 mb-6 flex-wrap">
        <button
          onClick={handleRecargar}
          disabled={cargando}
          className="px-4 py-2 bg-blue-500 text-white rounded-xl hover:bg-blue-600 transition-colors flex items-center gap-2 text-sm disabled:opacity-50"
        >
          <span>🔄</span>
          Actualizar Datos
        </button>

        {/* Estado */}
        {estado && (
          <div className="flex-1 min-w-0">
            <div className="bg-blue-50 border border-blue-200 rounded-lg p-2">
              <p className="text-blue-800 text-sm truncate">{estado}</p>
            </div>
          </div>
        )}
      </div>

      {/* Contenido de las pestañas */}
      {activeTab === 'transacciones' && (
        <TransaccionesPendientesTab
          contractService={contractService}
          frigorificoService={frigorificoService}
          address={address}
          onRecargar={handleRecargar}
          lotesPendientes={lotesPendientes}
        />
      )}

      {activeTab === 'cortes' && (
        <CortesTab
          contractService={contractService}
          frigorificoService={frigorificoService}
          address={address}
          onRecargar={handleRecargar}
          lotesProcesados={lotesProcesados}
        />
      )}
    </div>
  ); 
}